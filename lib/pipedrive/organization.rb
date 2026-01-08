module Pipedrive
  class Organization < Base

    def self.api_version
      'v2'
    end

    def self.field_class
      OrganizationField
    end

    # Override initialize to wrap V2 ID fields with LazyRelatedObject
    def initialize(attrs = {})
      super(attrs)

      # Wrap ID fields for V1-style hash access
      wrap_related_id_field(:owner_id, User)

      # V1 compatibility: address was flat fields (address_street_number, address_route, etc.)
      # V2 returns nested object: { "value": "...", "street_number": "123", ... }
      flatten_address_fields
    end

    # Flatten V2 nested address object to V1-style flat fields
    def flatten_address_fields
      return unless @table[:address]

      addr = case @table[:address]
        when Hash then @table[:address]
        when OpenStruct then @table[:address].to_h
        else return
      end

      # Store full address data for code that needs it
      @table[:address_data] = addr

      # V1 compatibility: address was a string, now it's nested with 'value'
      @table[:address] = addr['value'] || addr[:value]

      # Flatten nested fields to V1-style flat fields
      @table[:address_street_number] = addr['street_number'] || addr[:street_number]
      @table[:address_route] = addr['route'] || addr[:route]
      @table[:address_locality] = addr['locality'] || addr[:locality]
      @table[:address_admin_area_level_1] = addr['admin_area_level_1'] || addr[:admin_area_level_1]
      @table[:address_admin_area_level_2] = addr['admin_area_level_2'] || addr[:admin_area_level_2]
      @table[:address_country] = addr['country'] || addr[:country]
      @table[:address_postal_code] = addr['postal_code'] || addr[:postal_code]
      @table[:address_formatted_address] = addr['formatted_address'] || addr[:formatted_address]
      @table[:address_subpremise] = addr['subpremise'] || addr[:subpremise]
      @table[:address_sublocality] = addr['sublocality'] || addr[:sublocality]
    end

    # Lazy-load related resources
    lazy_load_relation :owner, :owner_id, 'User'
    alias_method :user, :owner

    # V1 compatibility: owner_name was included in nested org objects
    # V2 removed it, so we fetch from the owner sub-resource
    def owner_name
      owner&.name
    end

    def persons
      Person.all(nil, { query: { org_id: id } })
    end

    def deals
      Deal.all(nil, { query: { org_id: id } })
    end

    def add_follower(opts = {})
      res = post "#{resource_path}/#{id}/followers", :body => opts
      res.success? ? true : bad_response(res,opts)
    end

    def followers
      User.all(get "#{resource_path}/#{id}/followers")
    end

    class << self

      def find_or_create_by_name(name, opts={})
        find_by_name(name).first || create(opts.merge(:name => name))
      end

      def search(opts)
        res = get "#{resource_path}/search", query: opts
        res.success? ? res['data'] : bad_response(res,opts)
      end

      def find_by_name(name, opts={})
        res = search({ term: name, fields: "name", exact_match: true }.merge(opts))

        return unless org_id = res.fetch("items", nil)&.first&.fetch("item", nil)&.fetch("id", nil)

        find(org_id)
      end

    end
  end
end
