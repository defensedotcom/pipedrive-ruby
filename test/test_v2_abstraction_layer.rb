require 'helper'

class TestV2AbstractionLayer < Test::Unit::TestCase
  def setup
    Pipedrive.authenticate("some-token")
    # Clear field cache between tests
    Pipedrive::Deal.clear_field_cache!
  end

  context "custom field flattening on read" do
    setup do
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
end
