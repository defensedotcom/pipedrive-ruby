module Pipedrive
  class Deal < Base

    def self.api_version
      'v2'
    end

    def self.field_class
      DealField
    end

    # Transform create options for V2 API
    # Converts user_id → owner_id
    def self.transform_create_opts(opts)
      transformed = opts.dup

      # Convert user_id to owner_id for V2 API
      if transformed.key?(:user_id) || transformed.key?('user_id')
        user_id_value = transformed.delete(:user_id) || transformed.delete('user_id')
        transformed['owner_id'] = user_id_value if user_id_value
      end

      transformed
    end

    # Override initialize to alias V2 field names for backwards compatibility
    # V2 API returns 'owner_id', but V1 used 'user_id'
    # V2 returns IDs instead of nested objects, wrap with LazyRelatedObject
    def initialize(attrs = {})
      super(attrs)

      # Wrap ID fields with LazyRelatedObject for V1-style hash access
      # V1 returned: {"org_id": {"id": 123, "name": "Acme", "value": 123}}
      # V2 returns: {"org_id": 123}
      # Wrapper allows: deal.org_id["name"] to still work
      # NOTE: owner_id must be wrapped BEFORE aliasing to user_id
      wrap_related_id_field(:owner_id, User)
      wrap_related_id_field(:org_id, Organization)
      wrap_related_id_field(:person_id, Person)
      wrap_related_id_field(:creator_user_id, User)

      # Alias owner_id → user_id for backwards compatibility (after wrapping)
      if respond_to?(:owner_id) && !respond_to?(:user_id)
        @table[:user_id] = owner_id
      end
    end

    # Override update to transform user_id → owner_id for V2 API
    def update(opts = {})
      super(self.class.transform_create_opts(opts))
    end

    # Lazy-load related resources
    lazy_load_relation :organization, :org_id, 'Organization'
    lazy_load_relation :person, :person_id, 'Person'
    lazy_load_relation :user, :user_id, 'User'
    lazy_load_relation :stage, :stage_id, 'Stage'

    def add_product(opts = {})
      res = post "#{resource_path}/#{id}/products", :body => opts
      res.success? ? res['data']['product_attachment_id'] : bad_response(res,opts)
    end

    def products
      # V2 uses nested endpoint: GET /api/v2/deals/{id}/products
      Product.all(get "#{resource_path}/#{id}/products")
    end

    def add_participant(opts = {})
      res = post "#{resource_path}/#{id}/participants", :body => opts
      res.success? ? true : bad_response(res,opts)
    end

    def participants
      # V2 uses query params instead of nested endpoint
      Person.all(nil, { query: { deal_id: id } })
    end

    def add_follower(opts = {})
      res = post "#{resource_path}/#{id}/followers", :body => opts
      res.success? ? true : bad_response(res,opts)
    end

    def followers
      User.all(get "#{resource_path}/#{id}/followers")
    end

    def remove_product product_attachment_id
      res = delete "#{resource_path}/#{id}/products", { :body => { :product_attachment_id => product_attachment_id } }
      res.success? ? nil : bad_response(res,product_attachment_id)
    end

    def activities
      # V2 uses query params instead of nested endpoint
      Activity.all(nil, { query: { deal_id: id } })
    end

    def files
      File.all(get "#{resource_path}/#{id}/files")
    end

    def add_note content
      Note.create(deal_id: id, content: content)
    end

    def notes(opts = {:sort_by => 'add_time', :sort_mode => 'desc'})
      Note.all( get("/notes", :query => opts.merge(:deal_id => id) ) )
    end

    def delete
      res = delete "#{resource_path}/#{id}"
      res.success? ? nil : bad_response(res, id)
    end

  end
end
