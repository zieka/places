class Place
  include Mongoid::Document

  def self.mongo_client
    db = Mongo::Client.new('mongodb://localhost:27017')
  end

  def self.collection
    self.mongo_client['places']
  end

  def self.load_all(file)
    # accept a parameter of type IO with a JSON string of data
    # read the data from that input parameter (Note: this is similar handling an uploaded file within Rails)
    # parse the JSON string into an array of Ruby hash objects representing places (Hint: JSON.parse)
    # insert the array of hash objects into the places collection (Hint: insert_many)
    files = JSON.parse(file.read)
    collection.insert_many(files)    
  end


end
