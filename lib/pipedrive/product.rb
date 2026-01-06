module Pipedrive
  class Product < Base

    def self.api_version
      'v2'
    end

    def self.field_class
      ProductField
    end

    # Override initialize to wrap V2 ID fields with LazyRelatedObject
    def initialize(attrs = {})
      super(attrs)

      # Wrap ID fields for V1-style hash access
      wrap_related_id_field(:owner_id, User)
    end

    # Lazy-load owner from owner_id
    def owner
      return @owner if defined?(@owner)
      return nil unless owner_id

      @owner = case owner_id
      when Hash
        User.new(owner_id)
      when LazyRelatedObject
        User.find(owner_id.to_i)
      else
        User.find(owner_id)
      end
    end
  end
end
