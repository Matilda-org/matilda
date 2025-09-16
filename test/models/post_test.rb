require "test_helper"

class PostTest < ActiveSupport::TestCase
  test "formatting dei tags nel before_validation" do
    post = Post.new(tags: "ruby, rails, #test, rails")
    post.valid?
    assert_equal "#ruby #rails #test", post.tags
  end

  test "scope search trova post per content" do
    post = Post.create!(content: "Questo è un post di test", tags: "#test")
    results = Post.search("test")
    assert_includes results, post
  end

  test "scope search trova post per tags" do
    post = Post.create!(content: "Altro post", tags: "#speciale")
    results = Post.search("speciale")
    assert_includes results, post
  end

  test "image_thumb e image_large restituiscono variant" do
    post = Post.create!(content: "Questo è un post di test", tags: "#test")
    post.image.attach(io: File.open(Rails.root.join("test/fixtures/files/image.png")), filename: "image.png", content_type: "image/png")
    assert_not_nil post.image_thumb
    assert_not_nil post.image_large
  end
end
