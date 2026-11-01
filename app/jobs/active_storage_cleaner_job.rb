# ActiveStorageCleanerJob.
class ActiveStorageCleanerJob < ApplicationJob
  def perform
    # Only blobs abandoned for a day: younger ones may be uploads still waiting to be attached
    ActiveStorage::Blob.unattached.where(created_at: ...1.day.ago).find_each(&:purge)
  end
end
