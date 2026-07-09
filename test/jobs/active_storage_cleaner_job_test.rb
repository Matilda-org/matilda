require "test_helper"

class ActiveStorageCleanerJobTest < ActiveSupport::TestCase
  test "purges unattached blobs" do
    unattached = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("orphan"),
      filename: "orphan.txt",
      content_type: "text/plain"
    )

    ActiveStorageCleanerJob.perform_now

    assert_not ActiveStorage::Blob.exists?(unattached.id)
  end

  test "keeps attached blobs" do
    setting = Setting.create!(key: "logo", data: { type: "file" })
    setting.file.attach(io: StringIO.new("logo"), filename: "logo.txt", content_type: "text/plain")
    attached_blob_id = setting.file.blob.id

    ActiveStorageCleanerJob.perform_now

    assert ActiveStorage::Blob.exists?(attached_blob_id)
  end
end
