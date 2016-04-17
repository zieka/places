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
end
