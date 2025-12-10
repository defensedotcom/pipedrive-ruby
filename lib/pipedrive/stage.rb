module Pipedrive
  class Stage < Base

    def self.api_version
      'v2'
    end

    def self.deals(id)
      Deal.all(get "#{resource_path}/#{id}/deals", :query => {:everyone => 1})
    end
  end
end
