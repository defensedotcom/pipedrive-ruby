require 'date'

module Pipedrive
  class Activity < Base

    def self.api_version
      'v2'
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
        self[:organization] = Organization.find(org_id)
      end

      self[:organization]
    end

    # Gets the person associated to the activity
    #
    # @return [Person, nil]
    def person
      return @person if defined?(@person)
      return nil unless person_id
      @person = Person.find(person_id)
    end

    # Gets the user associated to the activity
    #
    # @return [User, nil]
    def user
      return @user if defined?(@user)
      return nil unless user_id
      @user = User.find(user_id)
    end

  end
end