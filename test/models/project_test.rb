require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  def setup
    @project = Project.new(
      code: "PRJ001",
      name: "Progetto Test",
      year: "2025",
      description: "Descrizione di test"
    )
  end

  test "validità di base" do
    assert @project.valid?
  end

  # test "validazione presenza code" do
  #   @project.code = nil
  #   assert_not @project.valid?
  #   assert_includes @project.errors[:code], "non può essere lasciato in bianco"
  # end

  test "validazione lunghezza code" do
    @project.code = "A" * 51
    assert_not @project.valid?
  end

  test "validazione presenza name" do
    @project.name = nil
    assert_not @project.valid?
    assert_includes @project.errors[:name], "non può essere lasciato in bianco"
  end

  test "validazione lunghezza name" do
    @project.name = "A" * 101
    assert_not @project.valid?
  end

  test "validazione presenza year" do
    @project.year = nil
    assert_not @project.valid?
    assert_includes @project.errors[:year], "non può essere lasciato in bianco"
  end

  test "validazione lunghezza year" do
    @project.year = "20255"
    assert_not @project.valid?
  end

  test "validazione lunghezza description" do
    @project.description = "A" * 256
    assert_not @project.valid?
  end

  test "enum archived_reason" do
    assert_equal Project.archived_reasons.keys.sort, [ "blocked_by_me", "blocked_by_other", "completed", "not_started", "other" ].sort
  end

  test "metodo name_2chars" do
    @project.name = "Test!"
    assert_equal "TE", @project.name_2chars
    @project.name = "A"
    assert_equal "AX", @project.name_2chars
  end

  test "metodo complete_code" do
    assert_equal "2025 - PRJ001", @project.complete_code
  end

  test "metodo complete_code_name" do
    assert_equal "2025 - PRJ001 - Progetto Test", @project.complete_code_name
  end

  test "metodo archived_reason_string (istanza)" do
    @project.archived_reason = "completed"
    assert_equal "Completato", @project.archived_reason_string
  end

  test "metodo archived_reason_string (classe)" do
    assert_equal "Completato", Project.archived_reason_string("completed")
    assert_equal "Altro", Project.archived_reason_string("other")
    assert_equal "Non iniziato", Project.archived_reason_string("not_started")
    assert_equal "Bloccato da cliente", Project.archived_reason_string("blocked_by_other")
    assert_equal "Bloccato da azienda", Project.archived_reason_string("blocked_by_me")
    assert_equal "Non definito", Project.archived_reason_string("unknown")
  end

  test "metodo default_code" do
    code = Project.default_code
    assert code.is_a?(String)
    assert_equal 6, code.length
  end
end
