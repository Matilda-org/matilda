require "test_helper"

class GlobalCacheTest < ActiveSupport::TestCase
  setup do
    Rails.cache.clear
    Folder.delete_all
    @folder1 = Folder.create!(name: "A", items_projects_count: 1, items_credentials_count: 2)
    @folder2 = Folder.create!(name: "B", items_projects_count: 3, items_credentials_count: 4)
    @global_cache = GlobalCache.new
  end

  test "folders returns all folders ordered by name" do
    result = @global_cache.folders
    assert_equal 2, result.size
    assert_equal [ "A", "B" ], result.map { |f| f[:name] }
    assert_equal [ @folder1.id, @folder2.id ], result.map { |f| f[:id] }
    assert_equal [ 1, 3 ], result.map { |f| f[:items_projects_count] }
    assert_equal [ 2, 4 ], result.map { |f| f[:items_credentials_count] }
  end

  test "folders uses cache and folders_reset clears cache" do
    @global_cache.folders
    Folder.create!(name: "C", items_projects_count: 5, items_credentials_count: 6)
    assert_equal 2, @global_cache.folders.size
    @global_cache.folders_reset
    assert_equal 3, @global_cache.folders.size
  end

  test "folders count only active projects and follow archiving" do
    project = Project.create!(code: "ACT", name: "Active", year: 2026)
    @folder1.folders_items.create!(resource: project)
    @folder1.folders_items.create!(resource: Project.create!(code: "ARC", name: "Archived", year: 2026, archived: true))
    assert_equal [ 1, 0 ], GlobalCache.new.folders.map { |f| f[:items_active_projects_count] }

    project.update!(archived: true)
    assert_equal [ 0, 0 ], GlobalCache.new.folders.map { |f| f[:items_active_projects_count] }
  end
end
