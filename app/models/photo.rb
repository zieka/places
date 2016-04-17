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

  # provide a class method called mongo_client that returns a MongoDB Client from
  # Mongoid referencing the default database from the config/mongoid.yml file (Hint: Mongoid::Clients.default)
  def self.mongo_client
    db = Mongoid::Clients.default
  end


end
