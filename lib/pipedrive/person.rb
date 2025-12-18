module Pipedrive
  class Person < Base

    def self.api_version
      'v2'
    end

    def self.field_class
      PersonField
    end

    # Lazy-load organization from org_id
    def organization
      return @organization if defined?(@organization)
      return nil unless org_id

      @organization = if org_id.is_a?(Hash)
        Organization.new(org_id)
      else
        Organization.find(org_id)
      end
    end

    class << self

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
