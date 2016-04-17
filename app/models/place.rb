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

end
