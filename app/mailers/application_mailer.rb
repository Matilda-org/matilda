class ApplicationMailer < ActionMailer::Base
  default from: APPLICATION_MAIL_FROM
  layout "mailer"

  def recover_password_mail(email, code)
    @code = code

    mail(
      to: email,
      subject: '🔑 Matilda | Recupero password',
      template_path: 'mailer'
    )
  end

  def login_success_mail(email, ip_address)
    @ip_address = ip_address

    mail(
      to: email,
      subject: '🔑 Matilda | Accesso al tuo account',
      template_path: 'mailer'
    )
  end

  def task_assigned_mail(email, task_id)
    @task = Task.find_by_id(task_id)
    return if @task.nil?

    mail(
      to: email,
      subject: '📋 Matilda | Ti è stato assegnato un task',
      template_path: 'mailer'
    )
  end
end
