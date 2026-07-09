require "test_helper"

class SlackServiceTest < ActiveSupport::TestCase
  setup { Rails.cache.clear }

  def with_token
    Setting.set("slack_bot_user_oauth_token", "xoxb-test")
  end

  # temporarily replaces RestClient.post with the given block, restoring it after
  def stub_rest_post(replacement)
    original = RestClient.method(:post)
    RestClient.define_singleton_method(:post, replacement)
    yield
  ensure
    RestClient.define_singleton_method(:post, original)
  end

  # stubs RestClient.post to return the given JSON payload
  def stub_post(payload)
    stub_rest_post(->(*) { payload.to_json }) { yield }
  end

  test "is invalid without a configured token" do
    service = SlackService.new

    assert_equal false, service.find_user_id("Mario", "Rossi")
    assert_equal false, service.create_channel("Project X")
    assert_equal false, service.post_message_to_channel("C1", "hello")
  end

  test "find_user_id matches by first and last name" do
    with_token
    payload = {
      "ok" => true,
      "members" => [
        { "id" => "U1", "profile" => { "first_name" => "Luisa", "last_name" => "Bianchi" }, "real_name" => "Luisa Bianchi" },
        { "id" => "U2", "profile" => { "first_name" => "Mario", "last_name" => "Rossi" }, "real_name" => "Mario Rossi" }
      ]
    }

    stub_post(payload) do
      assert_equal "U2", SlackService.new.find_user_id("Mario", "Rossi")
    end
  end

  test "find_user_id returns nil when no member matches" do
    with_token
    payload = { "ok" => true, "members" => [ { "id" => "U1", "profile" => { "first_name" => "Ada", "last_name" => "Lovelace" }, "real_name" => "Ada Lovelace" } ] }

    stub_post(payload) do
      assert_nil SlackService.new.find_user_id("Mario", "Rossi")
    end
  end

  test "find_user_id returns false when slack responds not ok" do
    with_token

    stub_post({ "ok" => false }) do
      assert_equal false, SlackService.new.find_user_id("Mario", "Rossi")
    end
  end

  test "create_channel returns the created channel" do
    with_token

    stub_post({ "ok" => true, "channel" => { "id" => "C123", "name" => "project-x" } }) do
      channel = SlackService.new.create_channel("Project X")
      assert_equal "C123", channel["id"]
    end
  end

  test "post_message_to_channel returns true on success" do
    with_token

    stub_post({ "ok" => true }) do
      assert SlackService.new.post_message_to_channel("C1", "hello")
    end
  end

  test "archive_channel returns false on failure" do
    with_token

    stub_post({ "ok" => false }) do
      assert_equal false, SlackService.new.archive_channel("C1")
    end
  end

  test "returns false and logs when the request raises" do
    with_token

    stub_rest_post(->(*) { raise RestClient::Exception }) do
      assert_equal false, SlackService.new.post_message_to_channel("C1", "hello")
    end
  end
end
