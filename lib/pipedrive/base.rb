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
      # Use PATCH for v2 resources, PUT for v1 resources
      http_method = self.class.api_version == 'v2' ? :patch : :put
      headers = HEADERS.dup
      headers.merge!("Content-Type" => "application/json") if http_method == :patch
      opts = opts.to_json if http_method == :patch
      res = send(http_method, "#{resource_path}/#{id}", :body => opts, headers: headers)
      if res.success?
        res['data'] = Hash[res['data'].map {|k, v| [k.to_sym, v] }]
        @table.merge!(res['data'])
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

    class << self
      # Returns the API version to use for this resource
      # Override in subclasses to specify v2
      #
      # @return [String] API version ('v1' or 'v2')
      def api_version
        'v1'
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

          # Apply authentication based on API version
          if api_version == 'v2'
            # v2 uses header authentication
            options[:headers] ||= {}
            options[:headers]['x-api-token'] = @api_token if @api_token
          end
          # v1 uses query parameter authentication (handled by default_params)

          super(path, options)
        end
      end

      # Sets the authentication credentials in a class variable.
      #
      # @param [String] token Pipedrive API token
      # @return [Hash] authentication credentials
      def authenticate(token)
        @api_token = token
        # v1 resources use query parameter authentication
        default_params :api_token => token
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
        res = post resource_path, :body => opts
        if res.success?
          res['data'] = opts.merge res['data']
          new(res)
        else
          bad_response(res,opts)
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
