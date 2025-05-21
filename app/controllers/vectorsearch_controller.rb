# frozen_string_literal: true

# VectorsearchController.
class VectorsearchController < ApplicationController
  before_action :validate_session_user_id!

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

  def text_to_checklist
    llm = Langchain::LLM::OpenAI.new(
      api_key: Setting.get("vectorsearch_openai_key"),
      default_options: { temperature: 0.25, chat_model: "gpt-4.1-mini" }
    )

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
    llm = Langchain::LLM::OpenAI.new(
      api_key: Setting.get("vectorsearch_openai_key"),
      default_options: { temperature: 0.25, chat_model: "gpt-4.1-mini" }
    )

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
end
