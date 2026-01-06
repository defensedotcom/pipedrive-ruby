module Pipedrive
  # A wrapper that acts as both an ID (integer) and a lazy-loaded related object
  # This provides backwards compatibility for V1-style code that accesses
  # related object fields like `deal.user_id["name"]` or `deal.org_id["value"]`
  #
  # In V1, fields like user_id, org_id, person_id returned nested objects
  # In V2, they return just the ID - this wrapper bridges the gap
  #
  # @example
  #   deal.user_id.to_i        # => 12345 (acts as integer)
  #   deal.user_id == 12345    # => true
  #   deal.user_id["name"]     # => "John" (lazy-loads User and returns name)
  #   deal.user_id["email"]    # => "john@example.com"
  #
  class LazyRelatedObject
    def initialize(id, resource_class)
      @id = id
      @resource_class = resource_class
      @loaded_object = nil
    end

    # Hash-style access triggers lazy load and returns the property
    # V1 returned objects like {"id" => 123, "name" => "John", "value" => 123}
    def [](key)
      key_s = key.to_s

      # V1 nested objects had "value" and "id" keys that returned the ID
      return @id if key_s == 'value' || key_s == 'id'

      obj = loaded_object
      return nil unless obj

      # Try direct attribute access first
      if obj.respond_to?(key_s)
        obj.send(key_s)
      elsif obj.respond_to?(:[])
        obj[key_s]
      end
    end

    # Act like an integer
    def to_i
      @id.to_i
    end

    def to_s
      @id.to_s
    end

    # Support numeric comparisons
    def ==(other)
      case other
      when Integer
        to_i == other
      when LazyRelatedObject
        to_i == other.to_i
      when Hash
        # V1 returned hashes, so compare IDs
        to_i == other['id'] || to_i == other[:id]
      else
        false
      end
    end

    def eql?(other)
      self == other
    end

    def hash
      @id.hash
    end

    # Coercion for arithmetic operations
    def coerce(other)
      [other, to_i]
    end

    # Respond to common integer methods
    def +(other)
      to_i + other
    end

    def -(other)
      to_i - other
    end

    def *(other)
      to_i * other
    end

    def /(other)
      to_i / other
    end

    def <(other)
      to_i < other
    end

    def >(other)
      to_i > other
    end

    def <=(other)
      to_i <= other
    end

    def >=(other)
      to_i >= other
    end

    def <=>(other)
      to_i <=> other.to_i
    end

    # For nil checks - we're not nil if we have an ID
    def nil?
      @id.nil?
    end

    def present?
      !@id.nil?
    end

    def blank?
      @id.nil?
    end

    # JSON serialization - return just the ID
    def as_json(*)
      @id
    end

    def to_json(*)
      @id.to_json
    end

    # For interpolation in strings
    def to_str
      @id.to_s
    end

    # Inspection for debugging
    def inspect
      "#<Pipedrive::LazyRelatedObject id=#{@id} resource=#{@resource_class.name}>"
    end

    # Allow method calls to be forwarded to the loaded object
    def method_missing(method, *args, &block)
      obj = loaded_object
      if obj&.respond_to?(method)
        obj.send(method, *args, &block)
      else
        super
      end
    end

    def respond_to_missing?(method, include_private = false)
      loaded_object&.respond_to?(method, include_private) || super
    end

    private

    def loaded_object
      return @loaded_object if defined?(@loaded_object) && @loaded_object
      return nil if @id.nil?

      @loaded_object = @resource_class.find(@id)
    rescue => e
      # If we can't load the object, return nil rather than crashing
      nil
    end
  end
end
