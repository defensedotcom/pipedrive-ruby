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

    # Lazy-load related resources
    lazy_load_relation :owner, :owner_id, 'User'
    alias_method :user, :owner

    # V1 compatibility: active_flag was replaced with is_deleted (negated)
    def active_flag
      return nil unless respond_to?(:is_deleted)

      !is_deleted
    end

    # V1 compatibility: selectable was renamed to is_linkable
    def selectable
      return nil unless respond_to?(:is_linkable)

      is_linkable
    end
  end
end
