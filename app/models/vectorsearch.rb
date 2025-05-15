class Vectorsearch
  attr_reader :user_id

  def initialize(user_id)
    @user_id = user_id
  end

  def user
    @user ||= User.find(@user_id)
  end

  def messages
    @messages ||= ((0..last_message_index).to_a.reverse.map do |index|
      Rails.cache.read("Vectorsearch/#{@user_id}/message_#{index}")
    end).reject(&:nil?).reverse
  end

  def last_message_index
    @last_message_index ||= Rails.cache.fetch("Vectorsearch/#{@user_id}/last_message_index") do
      0
    end
  end

  # Operations
  ##

  def send_message(content)
    # save user message in memory
    save_message_in_memory('user', content)
    send_ui_update

    # send custom message if user has not provided an OpenAI API key
    unless Setting.get('vectorsearch_openai_key')
      save_message_in_memory('assistant', no_api_key_message)
      send_ui_update
      return false
    end

    # get response message from bot response
    response_content = nil
    begin
      llm = Langchain::LLM::OpenAI.new(
        api_key: Setting.get('vectorsearch_openai_key'),
        default_options: { temperature: 0.7, chat_model: "gpt-4.1-mini" }
      )

      assistant = Langchain::Assistant.new(
        llm: llm,
        instructions: prompt_template.gsub('{{track_time_string}}', self.user.complete_name).gsub('{{user_id}}', self.user.id.to_s).gsub('{{date}}', Date.today.strftime('%d/%m/%Y')),
        tools: [
          VectorsearchTools::BrowserWebTool.new,
          VectorsearchTools::QueryDatabaseTool.new,
        ]
      )

      messages.each { |message| assistant.add_message(role: message[:role], content: message[:content]) }

      assistant.run(auto_tool_execution: true) 
      response_content = assistant.messages.last.content
    rescue StandardError => e
      Rails.logger.error("Error in Vectorsearch#send_message: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      response_content = "Mi dispiace, non sono riuscito a trovare una risposta a causa di un errore interno."
    end

    # save assistant message in memory
    save_message_in_memory('assistant', response_content)
    send_ui_update

    true
  end

  def clear_messages
    Rails.cache.delete_matched("Vectorsearch/#{@user_id}/*")
    @last_message_index = nil
    @messages = nil

    send_ui_update

    true
  end

  private

  def save_message_in_memory(role, content)
    Rails.cache.write("Vectorsearch/#{@user_id}/message_#{last_message_index + 1}", { role: role, content: content }, expires_in: 7.days)
    Rails.cache.write("Vectorsearch/#{@user_id}/last_message_index", last_message_index + 1)
    @last_message_index = nil
    @messages = nil
  end

  def send_ui_update
    Turbo::StreamsChannel.broadcast_replace_to "vectorsearch_#{@user_id}", target: "vectorsearch_#{@user_id}_chat", partial: 'layouts/application/vectorsearch__chat', locals: { vectorsearch: self }
  end

  def no_api_key_message
    "Ciao, sono l'<b>Assistente Virtuale</b>. Per utilizzarmi devi completare la configurazione in fase di registrazione di Matilda 🙂"
  end

  def prompt_template
    "
    Sei un assistente virtuale di nome Matilda che fornisce informazioni sui dati registrati in un software di Project management.\n
    Il software gestisce i progetti e i task ad esso associati.\n
    Le attività sono gestite tramite board che possono contenere i task o i progetti stessi.\n
    Stai chattando con l'utente di nome {{user_complete_name}}. Il suo ID è: {{user_id}}.\n
    Oggi è il giorno {{date}}.\n
    Rispondi in modo naturale e formale. Puoi utilizzare emoji per esprimere emozioni.
    Non utilizzare markdown o inviare codice.\n
    ".strip
  end
end
