require "test_helper"

class SettingTest < ActiveSupport::TestCase
  test "set e get restituiscono valore string" do
    Setting.set("chiave_test", "valore_test", "string")
    assert_equal "valore_test", Setting.get("chiave_test")
  end

  test "set e get restituiscono valore boolean" do
    Setting.set("chiave_bool", 1, "boolean")
    assert_equal true, Setting.get("chiave_bool")
    Setting.set("chiave_bool", 0, "boolean")
    assert_equal false, Setting.get("chiave_bool")
  end

  test "set e get restituiscono valore json" do
    Setting.set("chiave_json", { "a" => 1, "b" => 2 }, "json")
    assert_equal({ "a" => 1, "b" => 2 }, Setting.get("chiave_json"))
  end

  test "set e get restituiscono valore file" do
    file_path = Rails.root.join("test/fixtures/files/test.txt")
    Setting.set("chiave_file", Rack::Test::UploadedFile.new(file_path, "text/plain"), "file")
    url = Setting.get("chiave_file")
    assert_not_nil url
  end

  test "reset elimina le impostazioni" do
    Setting.set("reset_test1", "a")
    Setting.set("reset_test2", "b")
    assert_difference("Setting.count", -2) do
      Setting.reset("reset_test")
    end
  end

  test "key deve essere presente" do
    setting = Setting.new(key: nil)
    assert_not setting.valid?
    assert_includes setting.errors[:key], "non può essere lasciato in bianco"
  end

  test "key non deve superare 50 caratteri" do
    setting = Setting.new(key: "a" * 51)
    assert_not setting.valid?
    assert_includes setting.errors[:key], "è troppo lungo (il massimo è 50 caratteri)"
  end

  test "key deve essere unica (case insensitive)" do
    Setting.create!(key: "test")
    setting2 = Setting.new(key: "Test")
    assert_not setting2.valid?
    assert_includes setting2.errors[:key], "è già presente"
  end

  test "value restituisce valore json" do
    setting = Setting.new(key: "json_key", data: { "type" => "json", "value" => { "a" => 1 } })
    assert_equal({ "a" => 1 }, setting.value)
  end

  test "value restituisce valore string" do
    setting = Setting.new(key: "string_key", data: { "type" => "string", "value" => "ciao" })
    assert_equal "ciao", setting.value
  end

  test "value restituisce valore boolean true" do
    setting = Setting.new(key: "bool_key", data: { "type" => "boolean", "value" => 1 })
    assert_equal true, setting.value
  end

  test "value restituisce valore boolean false" do
    setting = Setting.new(key: "bool_key", data: { "type" => "boolean", "value" => 0 })
    assert_equal false, setting.value
  end

  test "value restituisce nil se file non allegato" do
    setting = Setting.new(key: "file_key", data: { "type" => "file", "value" => nil })
    assert_nil setting.value
  end
end
