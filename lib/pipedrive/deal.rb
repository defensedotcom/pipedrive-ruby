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
    def initialize(attrs = {})
      super(attrs)

      # Alias owner_id → user_id for backwards compatibility
      if respond_to?(:owner_id) && !respond_to?(:user_id)
        @table[:user_id] = owner_id
      end
    end

    # Override update to transform user_id → owner_id for V2 API
    def update(opts = {})
      super(self.class.transform_create_opts(opts))
    end

    # Lazy-load organization from org_id
    # V1 returned nested object, V2 returns just the ID
    def organization
      return @organization if defined?(@organization)
      return nil unless org_id

      @organization = if org_id.is_a?(Hash)
        # V1 style - already have the data
        Organization.new(org_id)
      else
        # V2 style - need to fetch
        Organization.find(org_id)
      end
    end

    # Lazy-load person from person_id
    def person
      return @person if defined?(@person)
      return nil unless person_id

      @person = if person_id.is_a?(Hash)
        Person.new(person_id)
      else
        Person.find(person_id)
      end
    end

    # Lazy-load user/owner from user_id
    def user
      return @user if defined?(@user)
      return nil unless user_id

      @user = if user_id.is_a?(Hash)
        User.new(user_id)
      else
        User.find(user_id)
      end
    end

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
