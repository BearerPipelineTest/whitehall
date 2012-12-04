require 'test_helper'

class Whitehall::Uploader::SpeechRowTest < ActiveSupport::TestCase
  setup do
    @attachment_cache = stub('attachment cache')
  end

  def basic_headings
    %w{old_url title summary body  type  delivered_by  delivered_on event_and_location  policy_1  policy_2  policy_3  policy_4  organisation country_1 country_2 country_3 country_4}
  end

  test "validates row headings" do
    assert_equal [], Whitehall::Uploader::SpeechRow.heading_validation_errors(basic_headings)
  end

  test "validation reports missing row headings" do
    keys = basic_headings - ['title']
    assert_equal ["missing fields: 'title'"], Whitehall::Uploader::SpeechRow.heading_validation_errors(keys)
  end

  test "validation reports extra row headings" do
    keys = basic_headings + ['extra_stuff']
    assert_equal ["unexpected fields: 'extra_stuff'"], Whitehall::Uploader::SpeechRow.heading_validation_errors(keys)
  end

  test "takes legacy url from the old_url column" do
    row = Whitehall::Uploader::SpeechRow.new({"old_url" => "http://example.com/old-url"}, 1, @attachment_cache)
    assert_equal "http://example.com/old-url", row.legacy_url
  end

  test "takes title from the title column" do
    row = Whitehall::Uploader::SpeechRow.new({"title" => "a-title"}, 1, @attachment_cache)
    assert_equal "a-title", row.title
  end

  test "takes body from the body column" do
    row = Whitehall::Uploader::SpeechRow.new({"body" => "Some body goes here"}, 1, @attachment_cache)
    assert_equal "Some body goes here", row.body
  end

  test "takes summary from the summary column" do
    row = Whitehall::Uploader::SpeechRow.new({"summary" => "a-summary"}, 1, @attachment_cache)
    assert_equal "a-summary", row.summary
  end

  test "finds speech type by slug in the speech type column" do
    row = Whitehall::Uploader::SpeechRow.new({"type" => "transcript"}, 1, @attachment_cache)
    assert_equal SpeechType::Transcript, row.speech_type
  end

  test "finds role appointment for person who delivered speech based on delivered_by column" do
    minister = create(:person)
    role = create(:ministerial_role)
    role_appointment = create(:role_appointment, role: role, person: minister)
    row = Whitehall::Uploader::SpeechRow.new({
      "delivered_by" => minister.slug,
      "delivered_on" => "16-May-12"
    }, 1, @attachment_cache)
    assert_equal role_appointment, row.role_appointment
  end

  test "finds up to 4 policies specified by slug in columns policy_1, policy_2, policy_3 and policy_4" do
    policy_1 = create(:published_policy, title: "Policy 1")
    policy_2 = create(:published_policy, title: "Policy 2")
    policy_3 = create(:published_policy, title: "Policy 3")
    policy_4 = create(:published_policy, title: "Policy 4")
    row = Whitehall::Uploader::SpeechRow.new({"policy_1" => policy_1.slug,
      "policy_2" => policy_2.slug,
      "policy_3" => policy_3.slug,
      "policy_4" => policy_4.slug
    }, 1, @attachment_cache)

    assert_equal [policy_1, policy_2, policy_3, policy_4], row.related_policies
  end

  test "takes location from the event_and_location column" do
    row = Whitehall::Uploader::SpeechRow.new({"event_and_location" => "a-location"}, 1, @attachment_cache)
    assert_equal "a-location", row.location
  end

  test "parses the delivered_on date from the delivered_on column" do
    row = Whitehall::Uploader::SpeechRow.new({"delivered_on" => "16-May-12"}, 1, @attachment_cache)
    assert_equal Date.parse("2012-05-16"), row.delivered_on
  end

  test "takes the first_published_at date from the delivered_on column" do
    row = Whitehall::Uploader::SpeechRow.new({"delivered_on" => "16-May-12"}, 1, @attachment_cache)
    assert_equal Date.parse("2012-05-16"), row.first_published_at
  end

  test "finds related countries using the country finder" do
    countries = 5.times.map { stub('country') }
    Whitehall::Uploader::Finders::CountriesFinder.stubs(:find).with("first", "second", "third", "fourth", anything, anything).returns(countries)
    row = Whitehall::Uploader::PublicationRow.new({
        "country_1" => "first",
        "country_2" => "second",
        "country_3" => "third",
        "country_4" => "fourth"
      }, 1, @attachment_cache)
    assert_equal countries, row.countries
  end
end
