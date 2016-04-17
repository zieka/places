class Photo
  include Mongoid::Document
  # a read/write attribute called id that will be of type String to hold the
  # String form of the GridFS file _id attribute
  # a read/write attribute called location that will be of type Point to hold
  # the location information of where the photo was taken.
  # a write-only (for now) attribute called contents that will be used to import
  # and access the raw data of the photo. This will have varying data types depending on context.
  attr_accessor :id, :location
  attr_writer :contents


  # initialize @id to the string form of _id and @location to the Point form of
  # metadata.location if these exist. The document hash is likely coming from
  # query results coming from mongo_client.database.fs.find.
  # create a default instance if no hash is present
  def initialize(hash={})
  	@id = hash[:_id].to_s unless hash[:_id].nil?
  	unless hash[:metadata].nil?
  		@location = Point.new(hash[:metadata][:location]) unless hash[:metadata][:location].nil?
  		@place = hash[:metadata][:place]
  	end
  end

  # provide a class method called mongo_client that returns a MongoDB Client from
  # Mongoid referencing the default database from the config/mongoid.yml file (Hint: Mongoid::Clients.default)
  def self.mongo_client
    db = Mongoid::Clients.default
  end

  # take no arguments
  # return true if the photo instance has been stored to GridFS (Hint: @id.nil?)
  def persisted?
    !@id.nil?
  end

  # check whether the instance is already persisted and do nothing (for now) if
  # already persisted (Hint: use your new persisted? method to determine if your instance has been persisted)
  # use the exifr gem to extract geolocation information from the jpeg image.
  # store the content type of image/jpeg in the GridFS contentType file property.
  # store the GeoJSON Point format of the image location in the GridFS metadata
  # file property and the object in class’ location property.
  # store the data contents in GridFS
  # store the generated _id for the file in the :id property of the Photo model instance.
  def save
    unless persisted?
      gps = EXIFR::JPEG.new(@contents).gps
      description = {}
      description[:content_type] = 'image/jpeg'
      description[:metadata] = {}
      @location = Point.new(:lng => gps.longitude, :lat => gps.latitude)
      description[:metadata][:location] = @location.to_hash
      description[:metadata][:place] = @place

      if @contents
        @contents.rewind
        grid_file = Mongo::Grid::File.new(@contents.read, description)
        @id = self.class.mongo_client.database.fs.insert_one(grid_file).to_s
      end
    else
      self.class.mongo_client.database.fs.find(:_id => BSON::ObjectId(@id))
        .update_one(:$set => {
          :metadata => {
            :location => @location.to_hash,
            :place => @place
          }
        })
    end
  end

  # accept an optional set of arguments for skipping into and limiting the results of a search
  # default the offset (Hint: skip) to 0 and the limit to unlimited
  # return a collection of Photo instances representing each file returned from the database (Hint: ...find.map {|doc| Photo.new(doc) })
  def self.all(skip = 0, limit = nil)
  	result = mongo_client.database.fs.find({}).skip(skip)
  	result = result.limit(limit) unless limit.nil?
  	result.map do |e|
  		Photo.new(e)
  	end
  end

  # accept a single String parameter for the id
  # locate the file associated with the id by converting it back to a BSON::ObjectId and using in an :_id query.
  # set the values of id and location witin the model class based on the properties returned from the query.
  # return an instance of the Photo model class
  def self.find(id)
    doc = mongo_client.database.fs.find(:_id => BSON::ObjectId(id)).first
    doc.nil? ? nil : Photo.new(doc)
  end

  # accept no arguments
  # read the data contents from GridFS for the associated file
  # return the data bytes
  def contents
    doc = self.class.mongo_client.database.fs.find_one(:_id => BSON::ObjectId(@id))
    if doc
      buffer = ""
      doc.chunks.reduce([]) do |x, e|
        buffer << e.data.data
      end
      return buffer
    end
  end

  # accept no arguments
  # delete the file and its contents from GridFS
  def destroy
  	self.class.mongo_client.database.fs.find(:_id => BSON::ObjectId(@id)).delete_one
  end

  # accept a maximum distance in meters
  # uses the near class method in the Place model and its location to locate places within a maximum distance of where the photo was taken.
  # limit the result to only the nearest matching place (Hint: limit())
  # limit the result to only the _id of the matching place document (Hint: projection())
  # returns zero or one BSON::ObjectIds for the nearby place found
  def find_nearest_place_id(max)
    place = Place.near(@location, max).limit(1).projection(:_id => 1).first
    place.nil? ? nil : place[:_id]
  end


end
