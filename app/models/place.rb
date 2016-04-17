class Place
  include Mongoid::Document

  def self.mongo_client
    db = Mongo::Client.new('mongodb://localhost:27017')
  end

  def self.collection
    self.mongo_client['places']
  end
end
