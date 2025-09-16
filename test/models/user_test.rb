require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "should be valid with valid attributes" do
    user = User.new(
      name: "Giulia",
      surname: "Bianchi",
      email: "giulia.bianchi+1@example.com",
      password: "password456",
      password_confirmation: "password456"
    )
    assert user.valid?
    assert user.save
  end

  test "name should be present" do
    user = User.new(
      name: "",
      surname: "Rossi",
      email: "test+name@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    assert_not user.valid?
  end

  test "surname should be present" do
    user = User.new(
      name: "Mario",
      surname: "",
      email: "test+surname@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    assert_not user.valid?
  end

  test "email should be present" do
    user = User.new(
      name: "Mario",
      surname: "Rossi",
      email: "",
      password: "password123",
      password_confirmation: "password123"
    )
    assert_not user.valid?
  end

  test "email should be valid format" do
    user = User.new(
      name: "Mario",
      surname: "Rossi",
      email: "invalid_email",
      password: "password123",
      password_confirmation: "password123"
    )
    assert_not user.valid?
  end

  test "email should be unique" do
    user1 = User.create!(
      name: "Mario",
      surname: "Rossi",
      email: "unique@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    user2 = User.new(
      name: "Luigi",
      surname: "Bianchi",
      email: "UNIQUE@EXAMPLE.COM",
      password: "password456",
      password_confirmation: "password456"
    )
    assert_not user2.valid?
  end

  test "password should be present on create" do
    user = User.new(
      name: "Mario",
      surname: "Rossi",
      email: "test+password@example.com",
      password: "",
      password_confirmation: ""
    )
    assert_not user.valid?
  end

  test "password should have minimum length" do
    user = User.new(
      name: "Mario",
      surname: "Rossi",
      email: "test+minlength@example.com",
      password: "123",
      password_confirmation: "123"
    )
    assert_not user.valid?
  end

  test "complete_name returns correct format" do
    user = User.new(
      name: "Mario",
      surname: "Rossi",
      email: "test+completename@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    assert_equal "Rossi Mario", user.complete_name
  end

  test "email should be downcased before save" do
    user = User.create!(
      name: "Luca",
      surname: "Verdi",
      email: "LUCA.VERDI+downcase@EXAMPLE.COM",
      password: "password789",
      password_confirmation: "password789"
    )
    assert_equal user.email.downcase, user.reload.email
  end
end
