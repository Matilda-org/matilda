require "test_helper"

class CredentialTest < ActiveSupport::TestCase
  def setup
    @credential = Credential.create!(
      name: "Test Credential",
      secure_username: "user123",
      secure_password: "pass123",
      secure_content: "content123"
    )
  end

  test "should be valid with valid attributes" do
    assert @credential.valid?
  end

  test "should encrypt secure fields" do
    # Verifica che la lettura restituisca il valore originale
    assert_equal "user123", @credential.secure_username
    assert_equal "pass123", @credential.secure_password
    assert_equal "content123", @credential.secure_content
  end

  test "log_view! should store the timestamp without touching updated_at" do
    updated_at = @credential.updated_at
    assert_nil @credential.last_viewed_at

    @credential.log_view!
    @credential.reload

    assert_not_nil @credential.last_viewed_at
    assert_equal updated_at.to_i, @credential.updated_at.to_i
    assert_equal 0, @credential.days_since_last_view
  end

  test "stale view color should flag never seen and forgotten credentials" do
    assert_equal "danger", @credential.stale_view_color
    assert_equal "Mai visualizzata", @credential.last_view_label

    @credential.update_column(:last_viewed_at, Credential::STALE_WARNING_DAYS.days.ago)
    assert_equal "warning", @credential.stale_view_color

    @credential.update_column(:last_viewed_at, Time.current)
    assert_equal "secondary", @credential.stale_view_color
    assert_equal "Vista oggi", @credential.last_view_label
  end

  test "least_recently_viewed should list never seen credentials first" do
    seen = Credential.create!(name: "Seen", secure_password: "x")
    seen.log_view!

    results = Credential.least_recently_viewed.to_a
    assert_operator results.index(@credential), :<, results.index(seen)
  end

  test "search scope should find credential by name" do
    results = Credential.search("test credential")
    assert_includes results, @credential
    results = Credential.search("nonexistent")
    assert_not_includes results, @credential
  end
end
