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

    # Explicit integer conversion
    def to_i
      @id.to_i
    end

    def to_s
      @id.to_s
    end

    # Custom equality - supports Hash comparison for V1 compatibility
    def ==(other)
      case other
      when Integer, LazyRelatedObject
        to_i == other.to_i
      when Hash
        to_i == other['id'] || to_i == other[:id]
      else
        false
      end
    end

    # For use as hash keys (must match custom ==)
    def eql?(other)
      self == other
    end

    def hash
      @id.hash
    end

    # Coercion for right-side arithmetic (e.g., 5 + lazy_obj)
    def coerce(other)
      [other, to_i]
    end

    def inspect
      "#<Pipedrive::LazyRelatedObject id=#{@id} resource=#{@resource_class.name}>"
    end

    # Delegate unknown methods to @id (Integer) or loaded object
    def method_missing(method, *args, &block)
      if @id.respond_to?(method)
        @id.send(method, *args, &block)
      elsif (obj = loaded_object)&.respond_to?(method)
        obj.send(method, *args, &block)
      else
        super
      end
    end

    def respond_to_missing?(method, include_private = false)
      @id.respond_to?(method, include_private) ||
        loaded_object&.respond_to?(method, include_private) ||
        super
    end

    # Custom Marshal serialization - store class name instead of class object
    def marshal_dump
      [@id, @resource_class.name]
    end

    def marshal_load(data)
      @id, class_name = data
      @resource_class = Object.const_get(class_name)
      @loaded_object = nil
    end

    private

    def loaded_object
      return @loaded_object if defined?(@loaded_object) && @loaded_object
      return nil if @id.nil?

      @loaded_object = @resource_class.find(@id)
    rescue StandardError
      nil
    end
  end
end
