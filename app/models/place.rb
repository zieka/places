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
  # return the result of the above query (Hint: collection.find.aggregate(...))
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
end
