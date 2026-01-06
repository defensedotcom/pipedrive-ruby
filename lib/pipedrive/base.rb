require 'httparty'
require 'ostruct'
require 'forwardable'

module Pipedrive

  # Globally set request headers
  HEADERS = {
    "User-Agent"    => "Ruby.Pipedrive.Api",
    "Accept"        => "application/json",
    "Content-Type"  => "application/x-www-form-urlencoded"
  }

  # Base class for setting HTTParty configurations globally
  class Base < OpenStruct

    include HTTParty

    headers HEADERS
    format :json

    extend Forwardable
    def_delegators 'self.class', :delete, :get, :post, :put, :patch, :resource_path, :bad_response

    attr_reader :data

    # Create a new Pipedrive::Base object.
    #
    # Only used internally
    #
    # @param [Hash] attributes
    # @return [Pipedrive::Base]
    def initialize(attrs = {})
      if attrs['data']
        struct_attrs = attrs['data']

        if attrs['additional_data']
          struct_attrs.merge!(attrs['additional_data'])
        end
        if attrs['related_objects']
          struct_attrs.merge!(initialize_related_objects(attrs['related_objects']))
        end
      else
        struct_attrs = attrs
      end

      # Flatten V2 custom_fields to top-level for backwards compatibility
      if struct_attrs.is_a?(Hash) && struct_attrs['custom_fields']
        struct_attrs.merge!(flatten_custom_fields(struct_attrs['custom_fields']))
      end

      super(struct_attrs)
    end

    # Create related objects from hash
    #
    # Only used internally (V1 API only - V2 does not return related_objects)
    #
    # @param [Hash] related_object_hash
    # @return [Hash]
    def initialize_related_objects related_object_hash
      related_objects = Hash.new
      # Create related objects if given
      related_object_hash.each do |key, value|
        # Check if the given class is defined for the related object
        class_name = "Pipedrive::" + key.capitalize
        if Object.const_defined?(class_name)
          related_object = Object::const_get(class_name).new(value.values.shift)
          related_objects[key] = related_object
        end
      end

      related_objects
    end

    # Flatten V2 custom_fields structure to V1-style top-level attributes
    #
    # V2 returns: { "custom_fields": { "hash_key": { "value": X, "currency": "EUR" } } }
    # V1 returned: { "hash_key": X, "hash_key_currency": "EUR" }
    #
    # This method converts V2 format back to V1 format for backwards compatibility
    #
    # @param [Hash] custom_fields_hash
    # @return [Hash] flattened custom fields
    def flatten_custom_fields(custom_fields_hash)
      return {} unless custom_fields_hash.is_a?(Hash)

      flattened = {}
      custom_fields_hash.each do |field_key, field_data|
        if field_data.is_a?(Hash)
          # Extract the primary value
          if field_data.key?('value')
            flattened[field_key] = field_data['value']
          elsif field_data.key?(:value)
            flattened[field_key] = field_data[:value]
          end

          # Extract subfields (currency, etc.) with suffix pattern
          field_data.each do |subfield_key, subfield_value|
            subfield_key_s = subfield_key.to_s
            next if subfield_key_s == 'value'
            flattened["#{field_key}_#{subfield_key_s}"] = subfield_value
          end
        else
          # Simple value, just copy it
          flattened[field_key] = field_data
        end
      end

      flattened
    end

    # Updates the object.
    #
    # @param [Hash] opts
    # @return [Boolean]
    def update(opts = {})
      http_method, request_opts = prepare_update_request(opts)
      res = send(http_method, "#{resource_path}/#{id}", request_opts)
      if res.success?
        data = res['data']
        # Flatten custom fields for V2 responses
        if data.is_a?(Hash) && data['custom_fields']
          data.merge!(flatten_custom_fields(data['custom_fields']))
        end
        data = Hash[data.map {|k, v| [k.to_sym, v] }]
        @table.merge!(data)
      else
        false
      end
    end

    # Destroys the object
    #
    # @return [HTTParty::Response] response
    def destroy
      res = delete "#{resource_path}/#{id}"
      res.ok? ? res : bad_response(res, id)
    end

    private

    # Prepares update request based on API version
    # V2 uses PATCH with JSON body, V1 uses PUT with form-encoded body
    #
    # @param [Hash] opts - the update parameters
    # @return [Array<Symbol, Hash>] - HTTP method and request options
    def prepare_update_request(opts)
      if self.class.api_version == 'v2'
        # Resolve option labels to IDs for V2 API
        resolved_opts = resolve_option_labels(opts)
        # Nest custom fields under 'custom_fields' key for V2 API
        nested_opts = self.class.nest_custom_fields(resolved_opts)
        headers = HEADERS.merge("Content-Type" => "application/json")
        [:patch, { body: nested_opts.to_json, headers: headers }]
      else
        [:put, { body: opts, headers: HEADERS }]
      end
    end

    # Resolves option labels (e.g., "Yes", "No") to their corresponding option IDs
    # V2 API requires option IDs, not labels
    #
    # @param [Hash] opts - the update parameters
    # @return [Hash] - parameters with option labels replaced by IDs
    def resolve_option_labels(opts)
      field_class = self.class.field_class
      return opts unless field_class

      resolved = {}
      opts.each do |key, value|
        resolved[key] = resolve_single_option(field_class, key.to_s, value)
      end
      resolved
    end

    # Resolves a single option value if it's a string matching an option label
    #
    # @param [Class] field_class - the field class (e.g., DealField)
    # @param [String] field_key - the custom field key
    # @param [Object] value - the value to potentially resolve
    # @return [Object] - the option ID if matched, otherwise original value
    def resolve_single_option(field_class, field_key, value)
      # Only process string values that could be option labels
      return value unless value.is_a?(String)

      # Look up field definition
      field = self.class.find_field_by_key(field_class, field_key)
      return value unless field&.options.is_a?(Array)

      # Find matching option by label
      option = field.options.find { |opt| opt['label'] == value }
      option ? option['id'] : value
    end

    class << self
      # Returns the API version to use for this resource
      # Override in subclasses to specify v2
      #
      # @return [String] API version ('v1' or 'v2')
      def api_version
        'v1'
      end

      # Returns the field class for this resource (e.g., DealField for Deal)
      # Override in subclasses that have custom fields
      #
      # @return [Class, nil] the field class or nil if not applicable
      def field_class
        nil
      end

      # Cache for field definitions, keyed by field key
      # Structure: { "field_key" => field_object }
      def field_cache
        @field_cache ||= {}
      end

      # Finds a field definition by its key, with caching
      #
      # @param [Class] field_class - the field class to query
      # @param [String] field_key - the field key to look up
      # @return [Object, nil] the field object or nil if not found
      def find_field_by_key(field_class, field_key)
        return field_cache[field_key] if field_cache.key?(field_key)

        # Fetch all fields and cache them (more efficient than individual lookups)
        unless @fields_loaded
          begin
            fields = field_class.all
            fields.each { |f| field_cache[f.key] = f if f.respond_to?(:key) }
            @fields_loaded = true
          rescue => e
            # If field lookup fails, don't break the update - just skip resolution
            return nil
          end
        end

        field_cache[field_key]
      end

      # Clears the field cache (useful for testing or when fields change)
      def clear_field_cache!
        @field_cache = {}
        @fields_loaded = false
      end

      # Nests custom field keys under 'custom_fields' for V2 API
      # Custom field keys are 40-character hexadecimal hashes
      #
      # @param [Hash] opts - the parameters
      # @return [Hash] - parameters with custom fields nested
      def nest_custom_fields(opts)
        standard_fields = {}
        custom_fields = {}

        opts.each do |key, value|
          key_s = key.to_s
          if custom_field_key?(key_s)
            custom_fields[key_s] = value
          else
            standard_fields[key_s] = value
          end
        end

        if custom_fields.any?
          standard_fields['custom_fields'] = custom_fields
        end

        standard_fields
      end

      # Checks if a key looks like a Pipedrive custom field key
      # Custom field keys are 40-character hexadecimal strings
      #
      # @param [String] key - the field key to check
      # @return [Boolean] - true if it looks like a custom field key
      def custom_field_key?(key)
        key.is_a?(String) && key.match?(/\A[a-f0-9]{40}\z/)
      end

      # Override in subclasses to transform options before create
      # Used by Person to convert phone/email fields for V2 API
      #
      # @param [Hash] opts - the create parameters
      # @return [Hash] - transformed parameters
      def transform_create_opts(opts)
        opts
      end

      # Resolves option labels (e.g., "Yes", "No") to their corresponding option IDs
      # V2 API requires option IDs, not labels
      # Class-level version for use in create
      #
      # @param [Hash] opts - the parameters
      # @return [Hash] - parameters with option labels replaced by IDs
      def resolve_option_labels(opts)
        return opts unless field_class

        resolved = {}
        opts.each do |key, value|
          resolved[key] = resolve_single_option(key.to_s, value)
        end
        resolved
      end

      # Resolves a single option value if it's a string matching an option label
      # Class-level version for use in create
      #
      # @param [String] field_key - the custom field key
      # @param [Object] value - the value to potentially resolve
      # @return [Object] - the option ID if matched, otherwise original value
      def resolve_single_option(field_key, value)
        # Only process string values that could be option labels
        return value unless value.is_a?(String)

        # Only look up custom fields (40-char hex keys), not standard fields
        return value unless custom_field_key?(field_key)

        # Look up field definition
        field = find_field_by_key(field_class, field_key)
        return value unless field&.options.is_a?(Array)

        # Find matching option by label
        option = field.options.find { |opt| opt['label'] == value }
        option ? option['id'] : value
      end

      # Returns the base URI for the resource based on its API version
      #
      # @return [String] Base URI
      def base_uri_for_version
        if api_version == 'v2'
          'https://api.pipedrive.com/api/v2'
        else
          'https://api.pipedrive.com/v1'
        end
      end

      # Override HTTParty methods to use dynamic base_uri and authentication
      [:get, :post, :put, :patch, :delete].each do |method|
        define_method(method) do |path, options = {}|
          self.base_uri(base_uri_for_version)

          token = Pipedrive::Base.api_token

          # Apply authentication based on API version
          if api_version == 'v2'
            # v2 uses header authentication
            options[:headers] ||= {}
            options[:headers]['x-api-token'] = token if token
          else
            # v1 uses query parameter authentication
            options[:query] ||= {}
            options[:query][:api_token] = token if token
          end

          super(path, options)
        end
      end

      # Sets the authentication credentials in a class variable.
      #
      # @param [String] token Pipedrive API token
      # @return [Hash] authentication credentials
      def authenticate(token)
        @api_token = token
      end

      # Get the API token (accessible from subclasses)
      def api_token
        @api_token
      end

      # A passthrough to allow for the authentication with and access to multiple accounts
      #
      # eg. Pipedrive::Deal.auth(API-KEY).find(DEAL-ID)
      def auth(token)
        authenticate(token)
        self
      end

      # Examines a bad response and raises an appropriate exception
      #
      # @param [HTTParty::Response] response
      def bad_response(response, params={})
        if response.class == HTTParty::Response
          raise HTTParty::ResponseError, response
        end
        raise StandardError, 'Unknown error'
      end

      def new_list( attrs )
        attrs['data'].is_a?(Array) ? attrs['data'].map {|data| self.new( 'data' => data ) } : []
      end

      def all(response = nil, options={},get_absolutely_all=false)
        res = response || get(resource_path, options)
        if res.ok?
          data = res['data'].nil? ? [] : res['data'].map{|obj| new(obj)}
          if get_absolutely_all && res['additional_data']['pagination'] && res['additional_data']['pagination'] && res['additional_data']['pagination']['more_items_in_collection']
            options[:query] = options[:query].merge({:start => res['additional_data']['pagination']['next_start']})
            data += self.all(nil,options,true)
          end
          data
        else
          bad_response(res,options)
        end
      end

      def create( opts = {} )
        request_opts = prepare_create_request(opts)
        res = post resource_path, request_opts
        if res.success?
          # For V2, don't merge original opts as they may have different field names
          # (e.g., 'email' vs 'emails'). V2 API returns complete data.
          # For V1, merge opts to ensure passed data is available if API doesn't return it.
          res['data'] = opts.merge(res['data']) unless api_version == 'v2'
          new(res)
        else
          bad_response(res,opts)
        end
      end

      # Prepares create request based on API version
      # V2 uses JSON body with nested custom fields, V1 uses form-encoded body
      #
      # @param [Hash] opts - the create parameters
      # @return [Hash] - request options for HTTParty
      def prepare_create_request(opts)
        if api_version == 'v2'
          # Transform opts for v2 API (subclasses can override transform_create_opts)
          transformed_opts = transform_create_opts(opts)
          # Resolve option labels to IDs for V2 API
          resolved_opts = resolve_option_labels(transformed_opts)
          # Nest custom fields under 'custom_fields' key for V2 API
          nested_opts = nest_custom_fields(resolved_opts)
          headers = HEADERS.merge("Content-Type" => "application/json")
          { body: nested_opts.to_json, headers: headers }
        else
          { body: opts, headers: HEADERS }
        end
      end

      def search opts
        res = get resource_path, query: opts
        res.ok? ? new_list(res) : bad_response(res, opts)
      end

      def find(id)
        res = get "#{resource_path}/#{id}"
        res.ok? ? new(res) : bad_response(res,id)
      end

      def find_by_name(name, opts={})
        res = get "#{resource_path}/find", :query => { :term => name }.merge(opts)
        res.ok? ? new_list(res) : bad_response(res,{:name => name}.merge(opts))
      end

      def destroy(id)
         res = delete "#{resource_path}/#{id}"
         res.ok? ? res : bad_response(res, id)
      end

      def resource_path
        # The resource path should match the camelCased class name with the
        # first letter downcased.  Pipedrive API is sensitive to capitalisation
        klass = name.split('::').last
        klass[0] = klass[0].chr.downcase
        klass.end_with?('y') ? "/#{klass.chop}ies" : "/#{klass}s"
      end
    end
  end

end
