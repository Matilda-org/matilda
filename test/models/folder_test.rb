require "test_helper"

class FolderTest < ActiveSupport::TestCase
  def setup
    @folder = Folder.new(name: "Test Folder")
  end

  test "valid with valid attributes" do
    assert @folder.valid?
  end

  test "invalid without name" do
    @folder.name = nil
    assert_not @folder.valid?
    assert_includes @folder.errors[:name], "non può essere lasciato in bianco"
  end

  test "invalid with too long name" do
    @folder.name = "a" * 51
    assert_not @folder.valid?
    assert_includes @folder.errors[:name], "è troppo lungo (il massimo è 50 caratteri)"
  end

  test "relations: folders_items" do
    assert_respond_to @folder, :folders_items
  end

  test "relations: projects" do
    assert_respond_to @folder, :projects
  end

  test "relations: credentials" do
    assert_respond_to @folder, :credentials
  end

  test "helper methods" do
    assert_respond_to @folder, :total_projects
    assert_respond_to @folder, :total_credentials
    assert_respond_to @folder, :last_project
    assert_respond_to @folder, :last_credential
  end
end
