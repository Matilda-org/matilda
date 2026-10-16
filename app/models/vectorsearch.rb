class Vectorsearch
  # Cheapest current OpenAI tier: newer and cheaper than gpt-5.4-nano, still good at tool calling.
  CHAT_MODEL = "gpt-6-luna"

  attr_reader :user_id

  # Shared OpenAI client for the assistant and the extraction helpers.
  # On Chat Completions this model runs function calling only with reasoning off,
  # and langchainrb drops params missing from its schema, so reasoning_effort is added there.
  def self.llm(temperature:)
    llm = Langchain::LLM::OpenAI.new(
      api_key: Setting.get("vectorsearch_openai_key"),
      default_options: { temperature: temperature, chat_model: CHAT_MODEL }
    )
    llm.chat_parameters.update(reasoning_effort: { default: "none" })
    llm
  end

  # Single-shot request for the form helpers: no tools, so no Assistant loop.
  # content can be a string or an OpenAI content array (text + image_url parts).
  # With json: true the model is forced to answer with a JSON object, returned parsed.
  def self.ask(instructions:, content:, json: false, temperature: 0.25)
    params = { messages: [ { role: "system", content: instructions }, { role: "user", content: content } ] }
    params[:response_format] = { type: "json_object" } if json

    answer = llm(temperature: temperature).chat(params).chat_completion
    json ? JSON.parse(answer) : answer.to_s.strip
  end

  # Inside the user's namespace, so clear_messages drops pending proposals too
  # and a user can never confirm someone else's proposal.
  def self.action_cache_key(user_id, action_id)
    "Vectorsearch/#{user_id}/action_#{action_id}"
  end

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
    save_message_in_memory("user", content)
    send_ui_update

    # send custom message if user has not provided an OpenAI API key
    unless Setting.get("vectorsearch_openai_key")
      save_message_in_memory("assistant", no_api_key_message)
      send_ui_update
      return false
    end

    # get response message from bot response
    response_content = nil
    actions_tool = VectorsearchTools::ActionsTool.new(user)
    begin
      llm = Vectorsearch.llm(temperature: 0.7)

      assistant = Langchain::Assistant.new(
        llm: llm,
        instructions: prompt_template.gsub("{{user_complete_name}}", self.user.complete_name).gsub("{{user_id}}", self.user.id.to_s).gsub("{{date}}", Date.today.strftime("%d/%m/%Y")),
        tools: [
          VectorsearchTools::BrowserWebTool.new,
          VectorsearchTools::QueryDatabaseTool.new(self.user),
          actions_tool
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

    # save assistant message in memory, with the proposals to confirm
    save_message_in_memory("assistant", response_content, actions_tool.proposals)
    send_ui_update

    true
  end

  def pending_action?(action_id)
    Rails.cache.exist?(Vectorsearch.action_cache_key(@user_id, action_id))
  end

  # Runs an action proposed by the assistant. No AI call: the click is the trigger.
  def confirm_action(action_id)
    key = Vectorsearch.action_cache_key(@user_id, action_id)
    action = Rails.cache.read(key)
    # only the request that deletes the entry runs it, so a double click runs it once
    return false unless action && Rails.cache.delete(key)

    result = VectorsearchTools::ActionsTool.new(user).execute(action[:type], action[:data])
    # in the history so the assistant knows the outcome in the next messages
    save_message_in_memory("assistant", result)
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

  def save_message_in_memory(role, content, actions = [])
    Rails.cache.write("Vectorsearch/#{@user_id}/message_#{last_message_index + 1}", { role: role, content: content, actions: actions }, expires_in: 7.days)
    Rails.cache.write("Vectorsearch/#{@user_id}/last_message_index", last_message_index + 1)
    @last_message_index = nil
    @messages = nil
  end

  def send_ui_update
    Turbo::StreamsChannel.broadcast_replace_to "vectorsearch_#{@user_id}", target: "vectorsearch_#{@user_id}_chat", partial: "layouts/application/vectorsearch__chat", locals: { vectorsearch: self }
  end

  def no_api_key_message
    "Ciao, sono l'<b>Assistente Virtuale</b>. Per utilizzarmi devi completare la configurazione in fase di registrazione di Matilda 🙂"
  end

  def prompt_template
    "
    Sei un assistente virtuale di nome Matilda che fornisce informazioni sui dati registrati in un software di Project management.\n
    Il software gestisce i progetti e i task ad esso associati.\n
    Le attività sono gestite tramite board che possono contenere i task o i progetti stessi.\n
    Il software ha anche un CRM: contatti (clienti e potenziali clienti), campagne e comunicazioni (un contatto dentro una campagna, con stato da inviare, inviata, persa o presa).\n
    Stai chattando con l'utente di nome {{user_complete_name}}. Il suo ID è: {{user_id}}.\n
    Oggi è il giorno {{date}}.\n
    Le azioni che modificano i dati vengono solo proposte: l'utente le esegue con il pulsante Conferma. Non dire mai che un'azione è stata eseguita finché l'utente non la conferma.\n
    Rispondi in modo naturale e formale. Puoi utilizzare emoji per esprimere emozioni.
    Non utilizzare markdown o inviare codice.\n
    ".strip
  end
end
