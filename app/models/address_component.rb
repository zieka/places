class AddressComponent
  # a read-only (String) attribute called long_name
  # a read-only (String) attribute called short_name
  # a read-only (array of Strings) attribute called types
  attr_reader :long_name, :short_name, :types

  # an initialize method that can set the attributes from a hash with keys long_name, short_name, and types.
  def initialize(params={})
    @long_name = params[:long_name]
    @short_name = params[:short_name]
    @types = params[:types]
  end
end
