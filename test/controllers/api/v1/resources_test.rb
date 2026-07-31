# frozen_string_literal: true

require "test_helper"

# Coverage for the smaller read-mostly API resources: tracks, procedures, posts, folders.
class Api::V1::ResourcesTest < ApiIntegrationTest
  # Tracks

  test "tracks index requires tasks_index policy and filters by date" do
    track = Tasks::Track.create!(task: tasks(:one), user: @user, start_at: Time.now, end_at: Time.now + 1.hour)
    assert_requires_policy :get, "/api/v1/tracks", "tasks_index"

    get "/api/v1/tracks", params: { date: Date.today.to_s }, headers: api_headers
    assert_includes json_response["data"].map { |t| t["id"] }, track.id

    get "/api/v1/tracks", params: { date: (Date.today - 7).to_s }, headers: api_headers
    assert_empty json_response["data"]
  end

  # Procedures

  test "procedures index requires procedures_index policy" do
    assert_requires_api_key :get, "/api/v1/procedures"
    assert_requires_policy :get, "/api/v1/procedures", "procedures_index"
    assert json_response["data"].any?
  end

  test "procedures show requires procedures_show policy and includes statuses" do
    assert_requires_policy :get, "/api/v1/procedures/#{procedures(:one).id}", "procedures_show"

    body = json_response
    assert_equal procedures(:one).id, body["id"]
    assert body.key?("procedures_statuses")
  end

  # Posts

  test "posts index requires posts_index policy" do
    assert_requires_policy :get, "/api/v1/posts", "posts_index"
    assert json_response["data"].any?
  end

  test "posts create requires posts_create policy and attributes the post to the api user" do
    assert_requires_policy :post, "/api/v1/posts", "posts_create",
      params: { content: "New post from API", tags: "api" },
      success_status: :created

    post = Post.order(:id).last
    assert_equal "New post from API", post.content
    assert_equal @user.id, post.user_id
  end

  # Folders

  test "folders index requires only a valid api key" do
    assert_requires_api_key :get, "/api/v1/folders"

    get "/api/v1/folders", headers: api_headers
    assert_response :success
    assert_includes json_response["data"].map { |f| f["id"] }, folders(:one).id
  end

  test "folders show scopes contained projects by membership policy" do
    folder = folders(:one)
    folder.folders_items.create!(resource: projects(:one))
    give_policy "only_data_projects_as_member"

    get "/api/v1/folders/#{folder.id}", headers: api_headers
    assert_response :success
    assert_empty json_response["projects"]
  end
end
