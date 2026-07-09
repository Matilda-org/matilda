require "test_helper"

class CachableTest < ActiveSupport::TestCase
  test "clears the views cache after save" do
    Rails.cache.write("views/some-fragment", "cached")
    post = posts(:one)

    post.update!(content: "Updated content")

    assert_nil Rails.cache.read("views/some-fragment")
  end

  test "clears the views cache after destroy" do
    Rails.cache.write("views/some-fragment", "cached")
    post = Post.create!(content: "Throwaway")

    post.destroy!

    assert_nil Rails.cache.read("views/some-fragment")
  end
end
