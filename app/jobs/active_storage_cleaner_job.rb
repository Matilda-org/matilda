# ActiveStorageCleanerJob.
class ActiveStorageCleanerJob < ApplicationJob
  def perform
    ActiveStorage::Blob.unattached.each(&:purge)
  end
end
