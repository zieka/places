class Place
  include Mongoid::Document

  # a read/write (String) attribute called id
  # a read/write (String) attribute called formatted_address
  # a read/write (Point) attribute called location
  # a read/write (collection of AddressComponents) attribute called address_components
  attr_accessor :id, :formatted_address, :location, :address_components


  # an initialize method to Place that can set the attributes from a hash with
  # keys _id, address_components, formatted_address, and geometry.geolocation.
  # (Hint: use .to_s to convert a BSON::ObjectId to a String and BSON::ObjectId.from_string(s) to convert it back again.)
  def initialize(params={})
    @id = params[:_id].to_s
    @formatted_address = params[:formatted_address]
    @location = Point.new(params[:geometry][:geolocation])
    @address_components = params[:address_components]
      .map{ |a| AddressComponent.new(a)} unless params[:address_components].nil?
  end



  def self.mongo_client
    db = Mongo::Client.new('mongodb://localhost:27017')
  end

  def self.collection
    self.mongo_client['places']
  end


  # accept a parameter of type IO with a JSON string of data
  # read the data from that input parameter (Note: this is similar handling an uploaded file within Rails)
  # parse the JSON string into an array of Ruby hash objects representing places (Hint: JSON.parse)
  # insert the array of hash objects into the places collection (Hint: insert_many)
  def self.load_all(file)
    files = JSON.parse(file.read)
    collection.insert_many(files)
  end

  # accept a String input parameter
  # find all documents in the places collection with a matching address_components.short_name
  # return the Mongo::Collection::View result
  def self.find_by_short_name(string)
    collection.find(:'address_components.short_name' => string)
  end

  # accept an input parameter
  # iterate over contents of that input parameter
  # change each document hash to a Place instance (Hint: Place.new)
  # return a collection of results containing Place objects
  def self.to_places(input)
    input.map do |e|
      Place.new(e)
    end
  end

  # accept a single String id as an argument
  # convert the id to BSON::ObjectId form (Hint: BSON::ObjectId.from_string(s))
  # find the document that matches the id
  # return an instance of Place initialized with the document if found (Hint: Place.new)
  def self.find(id)
    i = BSON::ObjectId.from_string(id)
    result = collection.find(:_id => i).first
    result.nil? ? nil : Place.new(result)
  end

  # accept two optional arguments: offset and limit in that order. offset must
  # default to no offset and limit must default to no limit
  # locate all documents within the places collection within paging limits
  # return each document as in instance of a Place within a collection
  def self.all(offset=0,limit=nil)
    result = collection.find({}).skip(offset)
    result = result.limit(limit) unless limit.nil?
    result = to_places(result)
  end

  # accept no arguments
  # delete the document from the places collection that has an _id associated with the id of the instance.
  def destroy
    self.class.collection.delete_one(:_id => BSON::ObjectId.from_string(@id))
  end

  # accept optional sort, offset, and limit parameters
  # extract all address_component elements within each document contained within the collection (Hint:$unwind)
  # return only the _id, address_components, formatted_address, and geometry.geolocation elements(Hint: $project)
  # apply a provided sort or no sort if not provided (Hint: $sort and q.pipeline method)
  # apply a provided offset or no offset if not provided (Hint: $skip and q.pipeline method)
  # apply a provided limit or no limit if not provided (Hint: $limit and q.pipeline method)
  # return the result of the above clause (Hint: collection.find.aggregate(...))
  def self.get_address_components(sort = nil, offset = 0, limit = nil)
    clause = [
      {
        :$unwind => '$address_components'
      },
      {
        :$project => {
          :address_components => 1,
          :formatted_address => 1,
          :'geometry.geolocation' => 1
        }
      }
    ]

    clause << {:$sort => sort} unless sort.nil?
    clause << {:$skip => offset} unless offset == 0
    clause << {:$limit => limit} unless limit.nil?

    collection.find.aggregate(clause)
  end

  # accept no arguments
  # create separate documents for address_components.long_name and
  # address_components.types (Hint:$project and $unwind)
  # select only those documents that have a address_components.types element
  # equal to "country" (Hint:$match)
  # form a distinct list based on address_components.long_name (Hint: $group)
  # return a simple collection of just the country names (long_name).
  # You will have to use application code to do this last step. (Hint: .to_a.map {|h| h[:_id]})
  def self.get_country_names
    clause = [
      {
        :$unwind => '$address_components'
      },
      {
        :$project => {
          :'address_components.long_name' => 1,
          :'address_components.types' => 1
        }
      },
      {
        :$match => {
          :"address_components.types" => "country"
        }
      },
      {
        :$group => {
          :"_id" => '$address_components.long_name'
        }
      }
    ]

    result = collection.find.aggregate(clause)
    result.to_a.map {|e| e[:_id]}
  end

  # accept a single country_code parameter
  # locate each address_component with a matching short_name being tagged with the country type (Hint:$match)
  # return only the _id property from the database (Hint: $project)
  # return only a collection of _ids converted to Strings (Hint: .map {|doc| doc[:_id].to_s})
  def self.find_ids_by_country_code(country_code)
    clause= [
      {
        :$match => {
          :"address_components.types" => "country",
          :"address_components.short_name" => country_code
        }
      },
      {
        :$project => {
          :_id => 1
        }
      }
    ]

    result = collection.find.aggregate(clause)
    result.to_a.map {|e| e[:_id].to_s }
  end

  # create_indexes must make sure the 2dsphere index is in place for the
  # geometry.geolocation property(Hint: Mongo::Index::GEO2DSPHERE)
  def self.create_indexes
    collection.indexes.create_one(:'geometry.geolocation' => Mongo::Index::GEO2DSPHERE)
  end

  # remove_indexes must make sure the 2dsphere index is removed from the collection
  # (Hint:Place.collection.indexes.map {|r| r[:name] } displays the names of each index)
  def self.remove_indexes
    collection.indexes.drop_one('geometry.geolocation_2dsphere')
  end

  # accept an input parameter of type Point (created earlier) and an optional
  # max_meters that defaults to no maximum
  # performs a $near search using the 2dsphere index placed on the
  # geometry.geolocation property and the GeoJSON output of point.to_hash
  # (created earlier). (Hint: Query a 2dsphere Index)
  # limits the maximum distance – if provided – in determining matches (Hint: $maxDistance)
  # returns the resulting view (i.e., the result of find())
  def self.near(point, max_meters= nil)
    clause = {
      :'geometry.geolocation' => {
        :$near => {
          :$geometry => point.to_hash,
          :$maxDistance => max_meters
        }
      }
    }

    collection.find(clause)
  end

  # accept an optional parameter that sets a maximum distance threshold in meters
  # locate all places within the specified maximum distance threshold
  # return the collection of matching documents as a collection of Place instances
  # using the to_places class method added earlier.
  def near(max_meters=nil)
    result = self.class.near(@location, max_meters)
    self.class.to_places(result)
  end

  # accept an optional set of arguments (offset, and limit) to skip into and
  # limit the result set. The offset should default to 0 and the limit should default to unbounded.
  def photos(offset = 0, limit = nil)
    result = []
    photos = Photo.find_photos_for_place(@id).skip(offset)
    photos = photos.limit(limit) unless limit.nil?

    photos.each do |e|
      result << Photo.new(e)
    end
    return result
  end
end
