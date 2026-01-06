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

    # Gets the organization associated to the activity
    #
    # @params [Boolean] force_reload
    # @return [Organization]
    def organization force_reload=false
      # Get Organization if id is set and if not already set
      if not org_id.nil? and (self[:organization].nil? or force_reload)
        org_id_value = org_id.is_a?(LazyRelatedObject) ? org_id.to_i : org_id
        self[:organization] = Organization.find(org_id_value)
      end

      self[:organization]
    end

    # Gets the person associated to the activity
    #
    # @return [Person, nil]
    def person
      return @person if defined?(@person)
      return nil unless person_id
      person_id_value = person_id.is_a?(LazyRelatedObject) ? person_id.to_i : person_id
      @person = Person.find(person_id_value)
    end

    # Gets the user associated to the activity
    #
    # @return [User, nil]
    def user
      return @user if defined?(@user)
      return nil unless user_id
      user_id_value = user_id.is_a?(LazyRelatedObject) ? user_id.to_i : user_id
      @user = User.find(user_id_value)
    end

    # Gets the deal associated to the activity
    #
    # @return [Deal, nil]
    def deal
      return @deal if defined?(@deal)
      return nil unless deal_id
      deal_id_value = deal_id.is_a?(LazyRelatedObject) ? deal_id.to_i : deal_id
      @deal = Deal.find(deal_id_value)
    end

  end
end