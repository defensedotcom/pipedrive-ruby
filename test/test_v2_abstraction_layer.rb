require 'helper'

class TestV2AbstractionLayer < Test::Unit::TestCase
  def setup
    Pipedrive.authenticate("some-token")
    # Clear field cache between tests
    Pipedrive::Deal.clear_field_cache!
  end

  context "custom field flattening on read" do
    setup do
      stub :get, "dealFields", "all_deal_fields_body.json", nil, 'v1'
      stub :get, "deals/123", "find_deal_with_custom_fields_body.json"
      @deal = ::Pipedrive::Deal.find(123)
    end

    should "flatten simple custom field value to top level" do
      assert_equal "Custom Value", @deal.a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2
    end

    should "flatten monetary custom field value to top level" do
      assert_equal 2500, @deal.b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3
    end

    should "flatten monetary custom field currency as suffix" do
      assert_equal "EUR", @deal.b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3_currency
    end

    should "flatten enum custom field option ID to top level" do
      assert_equal 128, @deal.c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4
    end

    should "also allow hash-style access to flattened fields" do
      assert_equal "Custom Value", @deal['a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2']
    end

    should "still have original custom_fields hash available" do
      assert @deal.custom_fields.is_a?(Hash)
      assert_equal "Custom Value", @deal.custom_fields['a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2']['value']
    end
  end

  context "custom field nesting on write" do
    setup do
      stub :get, "deals/123", "find_deal_with_custom_fields_body.json"
      stub :get, "dealFields", "all_deal_fields_body.json", nil, 'v1'
      @deal = ::Pipedrive::Deal.find(123)
    end

    should "nest custom fields under custom_fields key when updating" do
      # Stub the PATCH request and capture the body
      stub_request(:patch, "https://api.pipedrive.com/api/v2/deals/123")
        .with(
          headers: {
            'Accept' => 'application/json',
            'Content-Type' => 'application/json',
            'User-Agent' => 'Ruby.Pipedrive.Api',
            'x-api-token' => 'some-token'
          }
        ) { |request|
          body = JSON.parse(request.body)
          # Verify custom field is nested
          body['custom_fields'] &&
            body['custom_fields']['a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2'] == 'New Value'
        }
        .to_return(
          status: 200,
          body: File.read(File.join(File.dirname(__FILE__), "data", "update_deal_body.json")),
          headers: { 'Content-Type' => 'application/json' }
        )

      result = @deal.update({
        'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2' => 'New Value'
      })

      assert result
    end

    should "keep standard fields at top level when updating" do
      stub_request(:patch, "https://api.pipedrive.com/api/v2/deals/123")
        .with(
          headers: {
            'Accept' => 'application/json',
            'Content-Type' => 'application/json',
            'User-Agent' => 'Ruby.Pipedrive.Api',
            'x-api-token' => 'some-token'
          }
        ) { |request|
          body = JSON.parse(request.body)
          # Verify standard field is at top level, not nested
          body['title'] == 'New Title' && !body.dig('custom_fields', 'title')
        }
        .to_return(
          status: 200,
          body: File.read(File.join(File.dirname(__FILE__), "data", "update_deal_body.json")),
          headers: { 'Content-Type' => 'application/json' }
        )

      result = @deal.update({ 'title' => 'New Title' })

      assert result
    end
  end

  context "option label to ID resolution" do
    setup do
      # Stub deal fields endpoint
      stub :get, "dealFields", "all_deal_fields_body.json", nil, 'v1'
      stub :get, "deals/123", "find_deal_with_custom_fields_body.json"
      @deal = ::Pipedrive::Deal.find(123)
    end

    should "convert option label to ID when updating" do
      stub_request(:patch, "https://api.pipedrive.com/api/v2/deals/123")
        .with(
          headers: {
            'Accept' => 'application/json',
            'Content-Type' => 'application/json',
            'User-Agent' => 'Ruby.Pipedrive.Api',
            'x-api-token' => 'some-token'
          }
        ) { |request|
          body = JSON.parse(request.body)
          # Verify "Yes" was converted to 128
          body.dig('custom_fields', 'c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4') == 128
        }
        .to_return(
          status: 200,
          body: File.read(File.join(File.dirname(__FILE__), "data", "update_deal_body.json")),
          headers: { 'Content-Type' => 'application/json' }
        )

      result = @deal.update({
        'c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4' => 'Yes'
      })

      assert result
    end

    should "pass through option ID unchanged" do
      stub_request(:patch, "https://api.pipedrive.com/api/v2/deals/123")
        .with(
          headers: {
            'Accept' => 'application/json',
            'Content-Type' => 'application/json',
            'User-Agent' => 'Ruby.Pipedrive.Api',
            'x-api-token' => 'some-token'
          }
        ) { |request|
          body = JSON.parse(request.body)
          # Verify ID 129 was passed through unchanged
          body.dig('custom_fields', 'c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4') == 129
        }
        .to_return(
          status: 200,
          body: File.read(File.join(File.dirname(__FILE__), "data", "update_deal_body.json")),
          headers: { 'Content-Type' => 'application/json' }
        )

      result = @deal.update({
        'c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4' => 129
      })

      assert result
    end
  end

  context "custom field flattening on update response" do
    setup do
      stub :get, "deals/123", "find_deal_with_custom_fields_body.json"
      stub :get, "dealFields", "all_deal_fields_body.json", nil, 'v1'
      @deal = ::Pipedrive::Deal.find(123)
    end

    should "flatten custom fields from update response" do
      stub_request(:patch, "https://api.pipedrive.com/api/v2/deals/123")
        .with(
          headers: {
            'Accept' => 'application/json',
            'Content-Type' => 'application/json',
            'User-Agent' => 'Ruby.Pipedrive.Api',
            'x-api-token' => 'some-token'
          }
        )
        .to_return(
          status: 200,
          body: File.read(File.join(File.dirname(__FILE__), "data", "update_deal_body.json")),
          headers: { 'Content-Type' => 'application/json' }
        )

      @deal.update({ 'title' => 'Updated Deal' })

      # Verify flattened custom field was updated from response
      assert_equal "Updated Custom Value", @deal.a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2
      assert_equal 129, @deal.c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4
    end
  end

  context "lazy-loading related objects" do
    setup do
      stub :get, "dealFields", "all_deal_fields_body.json", nil, 'v1'
      stub :get, "deals/123", "find_deal_with_custom_fields_body.json"
      stub :get, "organizations/2", "find_organization_body.json"
      stub :get, "persons/2739", "find_person_body.json", nil, 'v2'
      stub :get, "users/1746472", "find_user_body.json", nil, 'v1'

      @deal = ::Pipedrive::Deal.find(123)
    end

    should "lazy-load organization" do
      org = @deal.organization

      assert org.instance_of?(::Pipedrive::Organization)
      assert_equal "Office San Francisco", org.name
    end

    should "lazy-load person" do
      person = @deal.person

      assert person.instance_of?(::Pipedrive::Person)
      assert_equal "Vincent Test", person.name
    end

    should "lazy-load user" do
      user = @deal.user

      assert user.instance_of?(::Pipedrive::User)
      assert_equal "Vincent Jaouen", user.name
    end

    should "cache lazy-loaded objects" do
      # First call triggers API request
      org1 = @deal.organization
      # Second call should return cached value (no additional stub needed)
      org2 = @deal.organization

      assert_equal org1.object_id, org2.object_id
    end
  end

  context "LazyRelatedObject wrapper" do
    setup do
      stub :get, "dealFields", "all_deal_fields_body.json", nil, 'v1'
      stub :get, "deals/123", "find_deal_with_custom_fields_body.json"
      @deal = ::Pipedrive::Deal.find(123)
    end

    should "wrap org_id as LazyRelatedObject" do
      assert @deal.org_id.is_a?(Pipedrive::LazyRelatedObject)
    end

    should "wrap person_id as LazyRelatedObject" do
      assert @deal.person_id.is_a?(Pipedrive::LazyRelatedObject)
    end

    should "wrap user_id as LazyRelatedObject (aliased from owner_id)" do
      assert @deal.user_id.is_a?(Pipedrive::LazyRelatedObject)
    end

    should "return ID with to_i" do
      assert_equal 2, @deal.org_id.to_i
    end

    should "return ID with to_s" do
      assert_equal "2", @deal.org_id.to_s
    end

    should "support equality with integer" do
      assert @deal.org_id == 2
      assert @deal.org_id != 3
    end

    should "support arithmetic operations" do
      assert_equal 3, @deal.org_id + 1
      assert_equal 1, @deal.org_id - 1
      assert_equal 4, @deal.org_id * 2
    end

    should "support comparison operations" do
      assert @deal.org_id > 1
      assert @deal.org_id < 3
      assert @deal.org_id >= 2
      assert @deal.org_id <= 2
    end

    should "return ID for ['value'] access (V1 compatibility)" do
      assert_equal 2, @deal.org_id['value']
    end

    should "return ID for ['id'] access (V1 compatibility)" do
      assert_equal 2, @deal.org_id['id']
    end

    should "lazy-load and return property for other keys" do
      stub :get, "organizations/2", "find_organization_body.json"

      assert_equal "Office San Francisco", @deal.org_id['name']
    end

    should "support hash-style equality (V1 compatibility)" do
      assert @deal.org_id == { 'id' => 2 }
      assert @deal.org_id == { :id => 2 }
    end
  end

  context "owner_id to user_id aliasing" do
    setup do
      stub :get, "dealFields", "all_deal_fields_body.json", nil, 'v1'
      stub :get, "deals/123", "find_deal_with_custom_fields_body.json"
      @deal = ::Pipedrive::Deal.find(123)
    end

    should "alias owner_id to user_id for backwards compatibility" do
      assert_equal @deal.owner_id.to_i, @deal.user_id.to_i
      assert_equal 1746472, @deal.user_id.to_i
    end
  end

  context "multi-option field formatting" do
    setup do
      stub :get, "dealFields", "all_deal_fields_body.json", nil, 'v1'
    end

    should "wrap single values in arrays for set (multi-option) fields" do
      stub_request(:post, "https://api.pipedrive.com/api/v2/deals")
        .with(
          headers: {
            'Accept' => 'application/json',
            'Content-Type' => 'application/json',
            'User-Agent' => 'Ruby.Pipedrive.Api',
            'x-api-token' => 'some-token'
          }
        ) { |request|
          body = JSON.parse(request.body)
          # Verify multi-option field was wrapped in array
          body.dig('custom_fields', 'd4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5') == [42]
        }
        .to_return(
          status: 200,
          body: File.read(File.join(File.dirname(__FILE__), "data", "create_deal_body.json")),
          headers: { 'Content-Type' => 'application/json' }
        )

      ::Pipedrive::Deal.create({
        title: 'Test Deal',
        'd4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5' => 42
      })
    end
  end

  context "empty text field filtering" do
    setup do
      stub :get, "dealFields", "all_deal_fields_body.json", nil, 'v1'
    end

    should "filter out empty string custom field values" do
      stub_request(:post, "https://api.pipedrive.com/api/v2/deals")
        .with(
          headers: {
            'Accept' => 'application/json',
            'Content-Type' => 'application/json',
            'User-Agent' => 'Ruby.Pipedrive.Api',
            'x-api-token' => 'some-token'
          }
        ) { |request|
          body = JSON.parse(request.body)
          # Verify empty custom field was NOT included
          !body.key?('custom_fields') || !body['custom_fields'].key?('e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6')
        }
        .to_return(
          status: 200,
          body: File.read(File.join(File.dirname(__FILE__), "data", "create_deal_body.json")),
          headers: { 'Content-Type' => 'application/json' }
        )

      ::Pipedrive::Deal.create({
        title: 'Test Deal',
        'e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6' => ''
      })
    end

    should "filter out nil custom field values" do
      stub_request(:post, "https://api.pipedrive.com/api/v2/deals")
        .with(
          headers: {
            'Accept' => 'application/json',
            'Content-Type' => 'application/json',
            'User-Agent' => 'Ruby.Pipedrive.Api',
            'x-api-token' => 'some-token'
          }
        ) { |request|
          body = JSON.parse(request.body)
          # Verify nil custom field was NOT included
          !body.key?('custom_fields') || !body['custom_fields'].key?('e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6')
        }
        .to_return(
          status: 200,
          body: File.read(File.join(File.dirname(__FILE__), "data", "create_deal_body.json")),
          headers: { 'Content-Type' => 'application/json' }
        )

      ::Pipedrive::Deal.create({
        title: 'Test Deal',
        'e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6' => nil
      })
    end
  end

  context "Person.person method" do
    setup do
      stub :get, "persons/2739", "find_person_body.json", nil, 'v2'
      @person = ::Pipedrive::Person.find(2739)
    end

    should "return self for V1 participants compatibility" do
      assert_equal @person.object_id, @person.person.object_id
    end

    should "allow hash-style access via person method" do
      assert_equal "Vincent Test", @person.person["name"]
    end
  end

  context "Deal.stage lazy-load" do
    setup do
      stub :get, "dealFields", "all_deal_fields_body.json", nil, 'v1'
      stub :get, "deals/123", "find_deal_with_custom_fields_body.json"
      stub :get, "stages/1", "find_stage_body.json", nil, 'v2'
      @deal = ::Pipedrive::Deal.find(123)
    end

    should "lazy-load stage" do
      stage = @deal.stage

      assert stage.instance_of?(::Pipedrive::Stage)
      assert_equal "Proposal Required", stage.name
    end
  end

  context "Deal.pipeline lazy-load" do
    setup do
      stub :get, "dealFields", "all_deal_fields_body.json", nil, 'v1'
      stub :get, "deals/123", "find_deal_with_custom_fields_body.json"
      stub :get, "pipelines/1", "find_pipeline_body.json", nil, 'v2'
      @deal = ::Pipedrive::Deal.find(123)
    end

    should "lazy-load pipeline" do
      pipeline = @deal.pipeline

      assert pipeline.instance_of?(::Pipedrive::Pipeline)
      assert_equal "Sales Pipeline", pipeline.name
    end
  end

  context "Organization.user alias" do
    setup do
      stub :get, "organizations/2", "find_organization_body.json"
      stub :get, "users/1746472", "find_user_body.json", nil, 'v1'
      @org = ::Pipedrive::Organization.find(2)
    end

    should "alias user to owner" do
      user = @org.user

      assert user.instance_of?(::Pipedrive::User)
      assert_equal "Vincent Jaouen", user.name
    end
  end

  context "Product.user alias" do
    setup do
      stub :get, "products/1", "find_product_body.json", nil, 'v2'
      stub :get, "users/1746472", "find_user_body.json", nil, 'v1'
      @product = ::Pipedrive::Product.find(1)
    end

    should "alias user to owner" do
      user = @product.user

      assert user.instance_of?(::Pipedrive::User)
      assert_equal "Vincent Jaouen", user.name
    end
  end

  context "reference-type custom field wrapping" do
    setup do
      stub :get, "dealFields", "all_deal_fields_body.json", nil, 'v1'
      stub :get, "deals/123", "find_deal_with_custom_fields_body.json"
      @deal = ::Pipedrive::Deal.find(123)
    end

    should "wrap org-type custom field with LazyRelatedObject" do
      # f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1 is field_type: org
      partner_org = @deal.f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1

      assert partner_org.is_a?(Pipedrive::LazyRelatedObject)
      assert_equal 99, partner_org.to_i
    end

    should "allow dig access on wrapped custom field" do
      stub :get, "organizations/99", "find_organization_body.json"

      partner_org = @deal.f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1
      assert_equal "Office San Francisco", partner_org.dig("name")
    end
  end

  context "Deal.weighted_value" do
    setup do
      stub :get, "dealFields", "all_deal_fields_body.json", nil, 'v1'
      stub :get, "deals/123", "find_deal_with_custom_fields_body.json"
      @deal = ::Pipedrive::Deal.find(123)
    end

    should "calculate weighted_value from value and probability" do
      # value: 5000, probability: 50 => weighted_value: 2500.0
      assert_equal 2500.0, @deal.weighted_value
    end

    should "return full value for won deals regardless of probability" do
      won_deal = ::Pipedrive::Deal.new({ 'value' => 5000, 'probability' => 50, 'status' => 'won' })
      assert_equal 5000.0, won_deal.weighted_value
    end

    should "return zero for lost deals regardless of probability" do
      lost_deal = ::Pipedrive::Deal.new({ 'value' => 5000, 'probability' => 50, 'status' => 'lost' })
      assert_equal 0.0, lost_deal.weighted_value
    end

    should "return nil if value is nil" do
      deal = ::Pipedrive::Deal.new({ 'value' => nil, 'probability' => 50, 'status' => 'open' })
      assert_nil deal.weighted_value
    end

    should "return nil if probability is nil for open deals" do
      deal = ::Pipedrive::Deal.new({ 'value' => 5000, 'probability' => nil, 'status' => 'open' })
      assert_nil deal.weighted_value
    end
  end

  context "Deal V1 convenience methods" do
    setup do
      stub :get, "dealFields", "all_deal_fields_body.json", nil, 'v1'
      stub :get, "deals/123", "find_deal_with_custom_fields_body.json"
      stub :get, "users/1746472", "find_user_body.json", nil, 'v1'
      stub :get, "organizations/2", "find_organization_body.json"
      stub :get, "persons/2739", "find_person_body.json"
      @deal = ::Pipedrive::Deal.find(123)
    end

    should "return owner_name from lazy-loaded user" do
      assert_equal "Vincent Jaouen", @deal.owner_name
    end

    should "return org_name from lazy-loaded organization" do
      assert_equal "Office San Francisco", @deal.org_name
    end

    should "return person_name from lazy-loaded person" do
      assert_equal "Vincent Test", @deal.person_name
    end

    should "return formatted_value with currency symbol and thousands separator" do
      assert_equal "US$5,000", @deal.formatted_value
    end

    should "return nil for formatted_value when value is nil" do
      deal = ::Pipedrive::Deal.new({ 'value' => nil, 'currency' => 'USD' })
      assert_nil deal.formatted_value
    end

    should "alias deleted to is_deleted" do
      deal = ::Pipedrive::Deal.new({ 'is_deleted' => true })
      assert_equal true, deal.deleted

      deal2 = ::Pipedrive::Deal.new({ 'is_deleted' => false })
      assert_equal false, deal2.deleted
    end
  end

  context "Organization V1 address field aliasing" do
    setup do
      stub :get, "organizations/2", "find_organization_v2_body.json"
      @org = ::Pipedrive::Organization.find(2)
    end

    should "flatten nested address to V1-style flat fields" do
      assert_equal "66", @org.address_street_number
      assert_equal "Mint St", @org.address_route
      assert_equal "San Francisco", @org.address_locality
      assert_equal "California", @org.address_admin_area_level_1
      assert_equal "San Francisco County", @org.address_admin_area_level_2
      assert_equal "United States", @org.address_country
      assert_equal "94103", @org.address_postal_code
      assert_equal "66 Mint St, San Francisco, CA 94103, United States", @org.address_formatted_address
    end

    should "return address as string (the value field)" do
      assert_equal "66 Mint St, San Francisco, CA 94103", @org.address
    end

    should "still have full address data available via address_data" do
      assert @org.address_data.is_a?(Hash)
      assert_equal "66", @org.address_data['street_number']
    end
  end

  context "Product V1 compatibility methods" do
    setup do
      stub :get, "products/1", "find_product_body.json"
      @product = ::Pipedrive::Product.find(1)
    end

    should "return active_flag as negation of is_deleted" do
      assert_equal true, @product.active_flag
    end

    should "return selectable as alias for is_linkable" do
      assert_equal true, @product.selectable
    end

    should "return false active_flag when is_deleted is true" do
      product = ::Pipedrive::Product.new({ 'is_deleted' => true, 'is_linkable' => false })
      assert_equal false, product.active_flag
      assert_equal false, product.selectable
    end
  end
end
