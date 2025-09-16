require "test_helper"

class PresentationTest < ActiveSupport::TestCase
  def setup
    @project = Project.create!(name: "Test Project", year: 2024)
    @presentation = Presentation.new(
      name: "Presentazione di test",
      width_px: 800,
      height_px: 600,
      project: @project,
    )
  end

  test "should be valid with valid attributes" do
    assert @presentation.valid?
  end

  test "should not be valid without name" do
    @presentation.name = nil
    assert_not @presentation.valid?
  end

  test "should not be valid with name longer than 50 chars" do
    @presentation.name = "a" * 51
    assert_not @presentation.valid?
  end

  test "should not be valid without width_px" do
    @presentation.width_px = nil
    assert_not @presentation.valid?
  end

  test "should not be valid without height_px" do
    @presentation.height_px = nil
    assert_not @presentation.valid?
  end

  test "shareable? returns true if share_code is present" do
    @presentation.share_code = "abc123"
    assert @presentation.shareable?
  end

  test "shareable? returns false if share_code is nil" do
    @presentation.share_code = nil
    assert_not @presentation.shareable?
  end

  test "import returns false if images is nil" do
    assert_not @presentation.import(nil)
  end

  # Puoi aggiungere altri test per il metodo import se necessario, ad esempio con immagini mockate
end
