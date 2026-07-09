require "test_helper"

class NotificationsManagerJobTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  test "marks unmanaged notifications as managed" do
    notification = Notification.create!(user: users(:one), typology: :general, managed: false, data: {})

    NotificationsManagerJob.perform_now

    assert notification.reload.managed
  end

  test "enqueues assignment mail for task_assigned notifications" do
    # assigning a user to a task auto-creates an unmanaged task_assigned notification
    Task.create!(title: "Assigned task", user: users(:one))
    assert Notification.where(managed: false, typology: :task_assigned).exists?

    assert_enqueued_emails 1 do
      NotificationsManagerJob.perform_now
    end
  end

  test "does not enqueue mail for general notifications" do
    Notification.create!(user: users(:one), typology: :general, managed: false, data: {})

    assert_no_enqueued_emails do
      NotificationsManagerJob.perform_now
    end
  end

  test "ignores already managed notifications" do
    Notification.create!(user: users(:one), typology: :task_assigned, managed: true, data: { task_id: 1 })

    assert_no_enqueued_emails do
      NotificationsManagerJob.perform_now
    end
  end
end
