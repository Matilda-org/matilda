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

  test "search scope should find credential by name" do
    results = Credential.search("test credential")
    assert_includes results, @credential
    results = Credential.search("nonexistent")
    assert_not_includes results, @credential
  end
end
