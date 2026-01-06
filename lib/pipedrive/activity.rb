require 'date'

module Pipedrive
  class Activity < Base

    def self.api_version
      'v2'
    end

    # Override initialize to wrap V2 ID fields with LazyRelatedObject
    def initialize(attrs = {})
      super(attrs)

      # Wrap ID fields for V1-style hash access
      # NOTE: owner_id must be wrapped BEFORE aliasing to user_id
      wrap_related_id_field(:owner_id, User)
      wrap_related_id_field(:org_id, Organization)
      wrap_related_id_field(:person_id, Person)
      wrap_related_id_field(:deal_id, Deal)

      # Alias owner_id → user_id for backwards compatibility (V2 renamed this field)
      if respond_to?(:owner_id) && !respond_to?(:user_id)
        @table[:user_id] = owner_id
      end
    end

    # Gets the date of the activity
    #
    # @return [DateTime]
    def date
      DateTime.parse(due_date + ' ' + due_time)
    end

    # Lazy-load related resources
    lazy_load_relation :organization, :org_id, 'Organization'
    lazy_load_relation :person, :person_id, 'Person'
    lazy_load_relation :user, :user_id, 'User'
    lazy_load_relation :deal, :deal_id, 'Deal'

  end
end