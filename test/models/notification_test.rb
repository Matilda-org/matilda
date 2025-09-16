require "test_helper"

class NotificationTest < ActiveSupport::TestCase
  test "enum typology values" do
    assert_equal({ "general"=>0, "task_assigned"=>1 }, Notification.typologies)
  end

  test "belongs to user" do
    assoc = Notification.reflect_on_association(:user)
    assert_equal :belongs_to, assoc.macro
  end

  test "can create notification with valid attributes" do
    user = User.create!(email: "test@example.com", password: "password", name: "Test", surname: "Test")
    notification = Notification.new(user: user, typology: :general)
    assert notification.valid?
    assert notification.save
  end

  test "invalid without user" do
    notification = Notification.new(typology: :general)
    assert_not notification.valid?
    assert_includes notification.errors[:user], "deve esistere"
  end

  test "invalid with wrong typology" do
    user = User.create!(email: "test2@example.com", password: "password", name: "Test2", surname: "Test2")
    assert_raises ArgumentError do
      notification = Notification.new(user: user, typology: :wrong_type)
      notification.save
    end
  end
end
