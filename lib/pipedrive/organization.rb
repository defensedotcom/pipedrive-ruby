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
    end

    # Lazy-load related resources
    lazy_load_relation :owner, :owner_id, 'User'

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
