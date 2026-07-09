require "test_helper"

class FolderableTest < ActiveSupport::TestCase
  setup do
    Rails.cache.clear
    @folder = folders(:one)
    @project = projects(:one)
  end

  test "for_folder scope returns only resources in the given folder" do
    @project.create_folders_item!(folder: @folder)

    assert_includes Project.for_folder(@folder.id), @project
  end

  test "without_folder scope returns resources not linked to any folder" do
    unfiled = Project.create!(code: "nofolder", name: "No Folder", year: 2026)
    @project.create_folders_item!(folder: @folder)

    assert_includes Project.without_folder, unfiled
    assert_not_includes Project.without_folder, @project
  end

  test "cached_folder_item_data returns folder info when present" do
    @project.create_folders_item!(folder: @folder)

    data = @project.cached_folder_item_data(true)

    assert_equal @folder.id, data[:folder_id]
    assert_equal @folder.name, data[:folder_name]
  end

  test "cached_folder_item_data returns nil without a folder item" do
    assert_nil @project.cached_folder_item_data(true)
  end
end
