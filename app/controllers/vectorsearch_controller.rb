# frozen_string_literal: true

# VectorsearchController.
class VectorsearchController < ApplicationController
  # images sent to the model for contact extraction (business cards, signatures)
  CONTACT_IMAGE_MAX_SIZE = 5.megabytes

  before_action :validate_session_user!

  def chat
    @vectorsearch = Vectorsearch.new(@session_user_id)
    render partial: "layouts/application/vectorsearch__chat", locals: { vectorsearch: @vectorsearch }
  end

  def send_message
    @vectorsearch = Vectorsearch.new(@session_user_id)
    @vectorsearch.send_message(params[:message])

    render partial: "layouts/application/vectorsearch__form"
  end

  def clear_messages
    @vectorsearch = Vectorsearch.new(@session_user_id)
    @vectorsearch.clear_messages

    render partial: "layouts/application/vectorsearch__chat", locals: { vectorsearch: @vectorsearch }
  end

  # Runs an action the assistant proposed (button under its answer).
  def confirm_action
    @vectorsearch = Vectorsearch.new(@session_user_id)
    @vectorsearch.confirm_action(params[:action_id])

    render partial: "layouts/application/vectorsearch__chat", locals: { vectorsearch: @vectorsearch }
  end

  def text_to_checklist
    llm = Vectorsearch.llm(temperature: 0.25)

    assistant = Langchain::Assistant.new(
      llm: llm,
      instructions: "Extract a checklist from the user message. Each item should be a separate line. Do not add any other text or formatting. Do not add - or other characters before the items. User the same language as the user message.",
    )
    assistant.add_message(role: "user", content: params[:text])

    assistant.run
    checklist = assistant.messages.last.content.split("\n").map { |item| item.strip }.reject(&:empty?)

    render json: checklist
  end

  def url_to_data
    llm = Vectorsearch.llm(temperature: 0.25)

    assistant = Langchain::Assistant.new(
      llm: llm,
      instructions: "Extract data from the URL provided by the user. The data should be in JSON format. The data should be formatted in this way: { content: 'String with a summary of the url content (max 200 characters)', tags: 'Comma separated list of tags', image_url: 'URL of the main image' }. Leave the fields empty if the data is not available. Do not add any other text or formatting. User the same language as the user message.",
      tools: [
        VectorsearchTools::BrowserWebTool.new
      ]
    )
    assistant.add_message(role: "user", content: params[:url])

    assistant.run(auto_tool_execution: true)
    data = assistant.messages.last.content
    data = JSON.parse(data) rescue nil

    render json: data || { error: "Invalid JSON format" }
  end

  # Drafts the first message (to_send) or the reminder (sent) of a CRM communication.
  def communication_draft
    return head(:forbidden) unless @session_user.policy?("crm")

    communication = Communication.includes(:contact, :campaign).find_by(id: params[:communication_id])
    return render(json: { error: "Comunicazione non trovata" }, status: :not_found) unless communication
    return render(json: { error: "La comunicazione è già chiusa" }, status: :unprocessable_entity) if communication.closed?

    draft = Vectorsearch.ask(
      instructions: communication_draft_instructions(communication),
      content: communication_draft_context(communication),
      temperature: 0.7
    )

    render json: { draft: draft }
  rescue StandardError => e
    ai_error_response(e)
  end

  # Turns free text (an email, a message) into the fields of the task form.
  def text_to_task
    return render(json: { error: "Testo mancante" }, status: :unprocessable_entity) if params[:text].blank?

    users = User.all.map { |u| "#{u.id}: #{u.complete_name}" }.join("\n")
    data = Vectorsearch.ask(
      json: true,
      instructions: <<~PROMPT,
        Extract a task from the user message and answer with a JSON object with these keys:
        title (short, max 80 characters), deadline (YYYY-MM-DD or null), time_estimate_minutes (integer or null),
        user_id (the assignee among the users below, or null), checklist (array of strings, empty if none).
        Today is #{Date.today.iso8601}: resolve relative dates. Use the same language as the user message.
        Users (id: name):
        #{users}
      PROMPT
      content: ActionView::Base.full_sanitizer.sanitize(params[:text])
    )

    render json: data.slice("title", "deadline", "time_estimate_minutes", "user_id", "checklist")
  rescue StandardError => e
    ai_error_response(e)
  end

  # Fills the contact form from pasted text (an email signature) and/or an image (a business card).
  def text_to_contact
    image = params[:image]
    return render(json: { error: "Inserisci un testo o un'immagine" }, status: :unprocessable_entity) if params[:text].blank? && image.blank?
    if image.present? && (!image.content_type.to_s.start_with?("image/") || image.size > CONTACT_IMAGE_MAX_SIZE)
      return render(json: { error: "L'immagine deve essere un file immagine di massimo 5 MB" }, status: :unprocessable_entity)
    end

    content = []
    content << { type: "text", text: params[:text] } if params[:text].present?
    content << { type: "image_url", image_url: { url: "data:#{image.content_type};base64,#{Base64.strict_encode64(image.read)}" } } if image.present?

    data = Vectorsearch.ask(
      json: true,
      instructions: <<~PROMPT,
        Extract a company or person contact from the user input (text and/or image) and answer with a JSON object with these keys:
        name, description (what they do, max 200 characters), email, phone, vat_number, website, address.
        Use null for missing values, never invent them. Prefer the company name when both company and person are present.
      PROMPT
      content: content
    )

    render json: data.slice("name", "description", "email", "phone", "vat_number", "website", "address")
  rescue StandardError => e
    ai_error_response(e)
  end

  private

  def communication_draft_instructions(communication)
    kind = communication.to_send? ? "the first message that presents the campaign to the contact" : "a polite reminder, since the contact has not answered yet"

    <<~PROMPT
      You write business emails for a CRM. Write #{kind}.
      Use the notes to personalize it and never invent facts, prices or dates that are not in the context.
      Write in Italian unless the context is clearly in another language. Keep it short (max 150 words).
      Answer with the email body only, starting from the greeting, signed by the sender. No subject, no markdown.
    PROMPT
  end

  def communication_draft_context(communication)
    contact = communication.contact
    campaign = communication.campaign
    notes = communication.communications_logs.recent_first.limit(10).map { |log| "- #{log.created_at.to_date.iso8601}: #{log.content.to_plain_text.squish}" }
    follow_ups = communication.communications_follow_ups.recent_first.map { |f| f.date.iso8601 }

    [
      "Sender: #{@session_user.complete_name}",
      "Contact: #{contact.name}#{" - #{contact.description}" if contact.description.present?}",
      "Campaign: #{campaign.name}#{" - #{campaign.description}" if campaign.description.present?}",
      ("Sent on: #{communication.sent_date.iso8601}" if communication.sent_date),
      ("Previous reminders: #{follow_ups.join(', ')}" if follow_ups.any?),
      ("Notes:\n#{notes.join("\n")}" if notes.any?)
    ].compact.join("\n")
  end

  def ai_error_response(error)
    Rails.logger.error("VectorsearchController##{action_name}: #{error.message}")
    render json: { error: "L'assistente non è riuscito a rispondere, riprova." }, status: :bad_gateway
  end
end
