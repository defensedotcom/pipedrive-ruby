require 'helper'

class TestPipedriveActivity < Test::Unit::TestCase
  def setup
    Pipedrive.authenticate("some-token")
  end

  context "create an activity" do
    setup do
      body = {
        "subject"   => "TEST",
        "type"      => "call",
        "person_id" => "2739",
        "due_date"  => "2017-10-04",
        "due_time"  => "11:00"
      }

      stub :post, "activities", "create_activity_body.json", body

      @activity = ::Pipedrive::Activity.create(body)
    end

    should "get a valid activity" do
      assert_equal "TEST", @activity.subject
      assert_equal "call", @activity.type
      assert_equal "2017/10/04 11:00", @activity.date.strftime("%Y/%m/%d %H:%M")
    end

    should "have person_id and user_id for lazy loading" do
      assert_equal 2739, @activity.person_id
      assert_equal 1746472, @activity.user_id
    end
  end

  context "find an activity" do
    setup do
      activity_id = 455
      organization_id = 2

      stub :get, "activities/#{activity_id}", "find_activity_body.json"
      stub :get, "organizations/#{organization_id}", "find_organization_body.json"

      @activity = Pipedrive::Activity.find(activity_id)
    end

    should "set attributes" do
      assert_equal "Follow up call", @activity.subject
      assert_equal "call", @activity.type
      assert_equal "2017/05/21 12:30", @activity.date.strftime("%Y/%m/%d %H:%M")
    end

    should "lazy-load associated organization" do
      organization = @activity.organization

      assert_equal "Office San Francisco", organization.name
    end
  end

  context "lazy-loading related objects" do
    setup do
      activity_id = 455
      person_id = 2671
      user_id = 123434

      stub :get, "activities/#{activity_id}", "find_activity_body.json"
      stub :get, "persons/#{person_id}", "find_person_body.json", nil, 'v2'
      stub :get, "users/#{user_id}", "find_user_body.json", nil, 'v1'

      @activity = Pipedrive::Activity.find(activity_id)
    end

    should "lazy-load person" do
      person = @activity.person

      assert person.instance_of?(::Pipedrive::Person)
      assert_equal "Vincent Test", person.name
    end

    should "lazy-load user" do
      user = @activity.user

      assert user.instance_of?(::Pipedrive::User)
      assert_equal "Vincent Jaouen", user.name
    end
  end

  should "return bad_response on errors" do
    #TODO
    # flunk "to be tested"
  end
end
