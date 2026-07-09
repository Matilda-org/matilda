require "test_helper"

class Projects::AttachmentTest < ActiveSupport::TestCase
  test "typology_string and typology_color map every typology" do
    expected = {
      "general" => [ "Altro", "secondary" ],
      "quotation_delivered" => [ "Preventivo inviato", "info" ],
      "quotation_accepted" => [ "Preventivo firmato", "success" ],
      "presentation" => [ "Presentazione progetto", "primary" ],
      "client_content" => [ "Materiale cliente", "warning" ]
    }

    expected.each do |typology, (string, color)|
      assert_equal string, Projects::Attachment.typology_string(typology)
      assert_equal color, Projects::Attachment.typology_color(typology)
    end
  end

  test "typology_color falls back to secondary for unknown values" do
    assert_equal "secondary", Projects::Attachment.typology_color("does_not_exist")
  end

  test "file_icon and color reflect the attached content type" do
    attachment = Projects::Attachment.create!(project: projects(:one), title: "Doc", date: Date.today)

    attachment.file.attach(io: StringIO.new("hi"), filename: "note.txt", content_type: "text/plain")
    assert_equal "bi-file-earmark-text", attachment.file_icon
    assert_equal "secondary", attachment.file_icon_color

    attachment.file.attach(io: StringIO.new("img"), filename: "photo.png", content_type: "image/png")
    assert_equal "bi-file-earmark-image", attachment.file_icon
    assert_equal "info", attachment.file_icon_color
  end

  test "file_icon falls back to a paperclip without an attached file" do
    attachment = Projects::Attachment.new(project: projects(:one), title: "Doc", date: Date.today)

    assert_equal "bi-paperclip", attachment.file_icon
    assert_equal "secondary", attachment.file_icon_color
  end
end
