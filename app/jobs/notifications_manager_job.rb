# NotificationsManagerjob.
class NotificationsManagerJob < ApplicationJob
  def perform
    Notification.where(managed: false).find_in_batches do |notifications|
      notifications.each do |notification|
        notification_data = notification.data.with_indifferent_access

        if notification.task_assigned?
          ApplicationMailer.task_assigned_mail(notification.user.email, notification_data[:task_id]).deliver_later
        end

        notification.managed = true
        notification.save!
      end
    end
  end
end