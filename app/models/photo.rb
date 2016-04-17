class Photo
  include Mongoid::Document

  # provide a class method called mongo_client that returns a MongoDB Client from
  # Mongoid referencing the default database from the config/mongoid.yml file (Hint: Mongoid::Clients.default)
  def self.mongo_client
    db = Mongoid::Clients.default
  end


end
