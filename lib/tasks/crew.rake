# frozen_string_literal: true

require "digest"
require "json"

namespace :crew do
  desc "Build the matilda-crew npm package into public/crew (requires npm)"
  task :pack do
    crew_dir = Rails.root.join("crew")
    output_dir = Rails.root.join("public", "crew")
    FileUtils.mkdir_p(output_dir)

    version = JSON.parse(File.read(crew_dir.join("package.json")))["version"]
    tarball = "matilda-crew-#{version}.tgz"

    # npm pack produces the canonical installable tarball (package/ root, files filter applied).
    system("npm pack --pack-destination #{output_dir}", chdir: crew_dir.to_s, exception: true)

    # Stable alias for the install command shown in the web UI; versioned URL used by `crew update`.
    FileUtils.cp(output_dir.join(tarball), output_dir.join("matilda-crew-latest.tgz"))

    manifest = {
      version: version,
      url: "/crew/#{tarball}",
      sha256: Digest::SHA256.file(output_dir.join(tarball)).hexdigest,
      packed_at: Time.now.utc.iso8601
    }
    File.write(output_dir.join("manifest.json"), JSON.pretty_generate(manifest) + "\n")

    puts "Packed matilda-crew #{version} -> public/crew/#{tarball}"
  end
end
