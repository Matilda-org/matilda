# frozen_string_literal: true

# SlackController.
class SlackController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :validate_slack_token

  def search_project_attachment
    return unless check_text_presence
    return unless find_project

    attachments = @project.projects_attachments.where("LOWER(title) LIKE :search", search: "%#{params[:text].downcase}%")
    unless attachments.length.positive?
      render plain: "Nessun allegato è stato trovato."
      return
    end

    service = SlackService.new
    message = "Allegati trovati per '#{params[:text]}'\n"
    attachments.each { |a| message += "Allegato #{a.title} (versione #{a.version}) - #{projects_show_attachment_url(a.id)}\n" }
    service.post_message_to_channel(@project.slack_channel_id, message)

    render plain: ""
  end

  def search_project_log
    return unless check_text_presence
    return unless find_project

    logs = @project.projects_logs.where("LOWER(title) LIKE :search", search: "%#{params[:text].downcase}%")
    unless logs.length.positive?
      render plain: "Nessun log è stato trovato."
      return
    end

    service = SlackService.new
    message = "Log trovati per '#{params[:text]}'\n"
    logs.each { |a| message += "Log #{a.title} del #{a.date.strftime('%d/%m/%Y')} - #{projects_show_log_url(id: a.id)}\n" }
    service.post_message_to_channel(@project.slack_channel_id, message)

    render plain: ""
  end

  private

  def validate_slack_token
    return true if params[:token] == Setting.get("slack_verification_token")

    render plain: "Per utilizzare questa funzione è necessario configurare correttamente Slack nelle impostazioni di Matilda."
    false
  end

  def check_text_presence
    return true unless params[:text].blank?

    render plain: "Per utilizzare questo comando devi inserire un contenuto nel messaggio."
    false
  end

  def find_project
    @project = Project.find_by(slack_channel_id: params[:channel_id])
    unless @project
      render plain: "Mi spiace, non trovo nessun progetto legato a questa chat."
      return false
    end

    true
  end
end
