# frozen_string_literal: true

require "test_helper"

class PostsControllerTest < ActionController::TestCase
  tests PostsController

  def setup
    setup_controller_test
  end

  test "actions" do
    post = posts(:one)
    matilda_controller_action("create", "Nuovo articolo")
    matilda_controller_action("edit", "Modifica articolo", post.id)
    matilda_controller_action("destroy", "Elimina articolo", post.id)
    matilda_controller_action_invalid
  end

  test "index" do
    matilda_controller_endpoint(:get, :index,
      policy: "posts_index"
    )
  end

  test "create_action" do
    matilda_controller_endpoint(:post, :create_action,
      params: { content: "Nuovo post", tags: "test", source_url: "http://example.com" },
      policy: "posts_create",
      title: "Nuovo articolo",
      feedback: "Articolo creato"
    )

    post = Post.find_by(content: "Nuovo post")
    assert_not_nil post
    assert_equal "#test", post.tags
    assert_equal "http://example.com", post.source_url
  end

  test "edit_action" do
    post = posts(:one)
    matilda_controller_endpoint(:post, :edit_action,
      params: { id: post.id, content: "Post aggiornato", tags: "updated,test", source_url: "http://updated.com" },
      policy: "posts_edit",
      title: "Modifica articolo",
      feedback: "Articolo aggiornato"
    )

    post.reload
    assert_equal "Post aggiornato", post.content
    assert_equal "#updated #test", post.tags
    assert_equal "http://updated.com", post.source_url
  end

  test "destroy_action" do
    post = posts(:one)
    matilda_controller_endpoint(:post, :destroy_action,
      params: { id: post.id },
      policy: "posts_destroy",
      title: "Elimina articolo",
      feedback: "Articolo eliminato"
    )

    assert_not Post.exists?(post.id)
  end
end
