require "test_helper"

class ProcedureTest < ActiveSupport::TestCase
  def setup
    @procedure = Procedure.new(
      name: "Test Procedure",
      description: "Descrizione di test",
      resources_type: :projects
    )
  end

  test "validità base" do
    assert @procedure.valid?
  end

  test "name obbligatorio" do
    @procedure.name = nil
    assert_not @procedure.valid?
    assert_includes @procedure.errors[:name], "non può essere lasciato in bianco"
  end

  test "name massimo 50 caratteri" do
    @procedure.name = "a" * 51
    assert_not @procedure.valid?
    assert_includes @procedure.errors[:name], "è troppo lungo (il massimo è 50 caratteri)"
  end

  test "description massimo 255 caratteri" do
    @procedure.description = "a" * 256
    assert_not @procedure.valid?
    assert_includes @procedure.errors[:description], "è troppo lungo (il massimo è 255 caratteri)"
  end

  test "scope not_archived" do
    @procedure.archived = false
    @procedure.save!
    assert_includes Procedure.not_archived, @procedure
  end

  test "scope archived" do
    @procedure.archived = true
    @procedure.save!
    assert_includes Procedure.archived, @procedure
  end

  test "scope as_model e not_as_model" do
    @procedure.model = true
    @procedure.save!
    assert_includes Procedure.as_model, @procedure
    @procedure.model = false
    @procedure.save!
    assert_includes Procedure.not_as_model, @procedure
  end

  test "resources_type_projects? e resources_type_tasks?" do
    @procedure.resources_type = "projects"
    assert @procedure.resources_type_projects?
    @procedure.resources_type = "tasks"
    assert @procedure.resources_type_tasks?
  end

  test "archivable?" do
    @procedure.model = false
    assert @procedure.archivable?
    @procedure.model = true
    assert_not @procedure.archivable?
  end

  test "clonable?" do
    @procedure.project_id = nil
    assert @procedure.clonable?
    @procedure.project_id = 1
    assert_not @procedure.clonable?
  end

  test "resources_type_string di classe" do
    assert_equal "Progetti", Procedure.resources_type_string("projects")
    assert_equal "Task", Procedure.resources_type_string("tasks")
    assert_equal "Non definito", Procedure.resources_type_string("altro")
  end

  test "resources_items_string di classe" do
    assert_equal "progetti", Procedure.resources_items_string("projects")
    assert_equal "task", Procedure.resources_items_string("tasks")
    assert_equal "elementi", Procedure.resources_items_string("altro")
  end

  test "resources_item_string di classe" do
    assert_equal "progetto", Procedure.resources_item_string("projects")
    assert_equal "task", Procedure.resources_item_string("tasks")
    assert_equal "elemento", Procedure.resources_item_string("altro")
  end

  test "capitalizzazione automatica del nome" do
    p = Procedure.create!(name: "test", resources_type: :projects)
    assert_equal "Test", p.name
  end
end
