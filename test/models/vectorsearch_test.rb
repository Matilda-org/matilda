require "test_helper"

class VectorsearchTest < ActiveSupport::TestCase
  setup do
    Rails.cache.clear
    @user = users(:one)
    Setting.set("vectorsearch_openai_key", "sk-test")
  end

  # Replaces Vectorsearch.chat with a fake whose ask returns the given answer
  # (or raises it), so the chat loop is tested without network.
  def with_chat_answer(answer)
    fake_chat = Object.new
    fake_chat.define_singleton_method(:ask) { |_content| answer.is_a?(Exception) ? raise(answer) : RubyLLM::Message.new(role: :assistant, content: answer) }
    %i[with_instructions with_tools add_message].each { |name| fake_chat.define_singleton_method(name) { |*, **| fake_chat } }

    original = Vectorsearch.method(:chat)
    Vectorsearch.define_singleton_method(:chat) { |**| fake_chat }
    yield
  ensure
    Vectorsearch.define_singleton_method(:chat, original)
  end

  test "the request turns reasoning off and sends every tool function" do
    payload = Vectorsearch.chat(temperature: 0.7)
      .with_tools(*VectorsearchTools::QueryDatabaseTool.new(@user).ruby_llm_tools)
      .tap { |chat| chat.add_message(role: :user, content: "ciao") }
      .render

    assert_equal Vectorsearch::CHAT_MODEL, payload[:model]
    assert_equal "none", payload.dig(:reasoning, :effort).to_s
    prjs = payload[:tools].find { |tool| tool[:name] == "prjs" }
    assert_equal "Query list of projects", prjs[:description]
    assert_equal "boolean", prjs.dig(:parameters, "properties", "archived", "type")
  end

  test "a failing tool function answers the model with the error" do
    query_tool = VectorsearchTools::QueryDatabaseTool.new(@user)
    query_tool.define_singleton_method(:prjs) { |_data| raise "boom" }
    tool = query_tool.ruby_llm_tools.find { |t| t.name == "prjs" }

    assert_match "boom", tool.call(search: "x")[:error]
  end

  test "send_message stores the model answer" do
    with_chat_answer("Ecco i progetti") { Vectorsearch.new(@user.id).send_message("progetti?") }

    assert_equal "Ecco i progetti", Vectorsearch.new(@user.id).messages.last[:content]
  end

  test "an empty answer shows the error message instead of an empty bubble" do
    with_chat_answer("") { Vectorsearch.new(@user.id).send_message("progetti?") }

    assert_match "errore interno", Vectorsearch.new(@user.id).messages.last[:content]
  end
end
