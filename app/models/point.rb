class Point
# a read/write (Integer) attribute called longitude (Hint: attr_accessor)
# a read/write (Integer) attribute called latitude (Hint: attr_accessor)
  attr_accessor :longitude, :latitude

  # an initialize method that can set the attributes from a hash with keys lat and lng or GeoJSON Point format.
  def initialize(params)
    unless params[:coordinates].nil?
      @longitude = params[:coordinates][0]
      @latitude = params[:coordinates][1]
    else
      @longitude = params[:lng]
      @latitude = params[:lat]
    end
  end

  # a to_hash instance method that will produce a GeoJSON Point hash (Hint: see example below)
  def to_hash
    {
      :type =>"Point",
      :coordinates => [@longitude, @latitude]
    }
  end

end
