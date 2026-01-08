module Pipedrive
  class Person < Base

    def self.api_version
      'v2'
    end

    def self.field_class
      PersonField
    end

    # Override initialize to alias V2 field names for backwards compatibility
    # V2 API returns 'phones' and 'emails', but V1 used 'phone' and 'email'
    # V2 returns IDs instead of nested objects for related fields
    def initialize(attrs = {})
      super(attrs)

      # Alias phones → phone for backwards compatibility
      if respond_to?(:phones) && !respond_to?(:phone)
        @table[:phone] = phones
      end

      # Alias emails → email for backwards compatibility
      if respond_to?(:emails) && !respond_to?(:email)
        @table[:email] = emails
      end

      # V1 compatibility: V1 always returned at least one entry even when empty
      # V2 returns empty array, which breaks code expecting phone.first['value']
      if @table[:phone].nil? || @table[:phone].empty?
        @table[:phone] = [{ 'value' => '', 'primary' => true }]
      end

      if @table[:email].nil? || @table[:email].empty?
        @table[:email] = [{ 'value' => '', 'primary' => true }]
      end

      # Wrap ID fields for V1-style hash access
      wrap_related_id_field(:org_id, Organization)
      wrap_related_id_field(:owner_id, User)
    end

    # Lazy-load related resources
    lazy_load_relation :organization, :org_id, 'Organization'
    lazy_load_relation :owner, :owner_id, 'User'

    # V1 compatibility: deal.participants returned objects with a .person attribute
    # V2 returns Person objects directly, so .person returns self
    def person
      self
    end

    class << self

      # Transform create options for V2 API
      # Converts phone → phones and email → emails with proper array-of-objects format
      #
      # @param [Hash] opts - the create parameters
      # @return [Hash] - transformed parameters
      def transform_create_opts(opts)
        transform_update_opts(opts)
      end

      # Transform update options for V2 API
      # Converts phone → phones and email → emails, handling both simple values and arrays
      #
      # @param [Hash] opts - the update parameters
      # @return [Hash] - transformed parameters
      def transform_update_opts(opts)
        transformed = opts.dup

        # Convert phone to phones array format
        if transformed.key?(:phone) || transformed.key?('phone')
          phone_value = transformed.delete(:phone) || transformed.delete('phone')
          transformed['phones'] = convert_to_contact_array(phone_value, 'work') if phone_value
        end

        # Convert email to emails array format
        if transformed.key?(:email) || transformed.key?('email')
          email_value = transformed.delete(:email) || transformed.delete('email')
          transformed['emails'] = convert_to_contact_array(email_value, 'work') if email_value
        end

        transformed
      end

      # Convert a value (string or array) to V2 contact array format
      # V2 format: [{ "value": "...", "primary": true/false, "label": "..." }]
      #
      # @param [String, Array] value - the contact value(s)
      # @param [String] label - the label for the contact (e.g., 'work', 'home')
      # @return [Array<Hash>] - array of contact objects
      def convert_to_contact_array(value, label)
        values = value.is_a?(Array) ? value : [value]
        values.map.with_index do |v, i|
          { 'value' => v.to_s, 'primary' => i == 0, 'label' => label }
        end
      end

      def find_or_create_by_name(name, opts={})
        find_by_name(name, :org_id => opts[:org_id]).first || create(opts.merge(:name => name))
      end

      def search(opts)
        res = get "#{resource_path}/search", query: opts
        res.success? ? res['data'] : bad_response(res,opts)
      end

      def find_by_name(name, opts={})
        res = search({ term: name, fields: "name", exact_match: true }.merge(opts))

        return unless person_id = res.fetch("items", nil)&.first&.fetch("item", nil)&.fetch("id", nil)

        find(person_id)
      end

    end

    # Override update to transform phone/email fields for V2 API
    def update(opts = {})
      super(self.class.transform_update_opts(opts))
    end

    def deals
      Deal.all(nil, { query: { person_id: id } })
    end

    def merge(opts = {})
      # Use PATCH for v2 resources, PUT for v1 resources
      http_method = self.class.api_version == 'v2' ? :patch : :put
      res = send(http_method, "#{resource_path}/#{id}/merge", :body => opts)
      res.success? ? res['data'] : bad_response(res,opts)
    end

    def add_follower(opts = {})
      res = post "#{resource_path}/#{id}/followers", :body => opts
      res.success? ? true : bad_response(res,opts)
    end

    def followers
      User.all(get "#{resource_path}/#{id}/followers")
    end

  end
end
