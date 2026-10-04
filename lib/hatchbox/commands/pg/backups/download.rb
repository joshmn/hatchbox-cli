# frozen_string_literal: true

module Hatchbox
  module Commands
    module Pg
      module Backups
        class Download < Hatchbox::Command
          include Hatchbox::Commands::Pg::Backups::Tools

          MAX_REDIRECTS = 3

          describe "pg:backups:download",
            summary: "download the latest backup",
            usage: "pg:backups:download [DATABASE]",
            args: { database: "[DATABASE]" },
            flags: [["-o", "--output FILE", "where to write it, the backup's own file name unless you say otherwise"]]

          def call
            record = one_database
            data = client.get("/databases/#{record["id"]}/backups/latest").json || {}
            url = data["url"].to_s
            raise Hatchbox::Error, "Hatchbox returned no download URL." if url.empty?

            output = options.output || default_name(url)
            raise Hatchbox::Error, "#{output} already exists. Pick another name with --output." if File.exist?(output) && options.output.nil?

            ui.action("Downloading backup of #{record["name"]} from #{formatter.short_date(data["last_backup_at"])} to #{output}") do |step|
              size = fetch(uri: URI.parse(url), output: output)
              step.status = "done, #{megabytes(size)}"
            end
            0
          end

          private

          def default_name(url)
            name = File.basename(URI.decode_www_form_component(URI.parse(url).path.to_s))
            name.empty? || name == "/" ? "latest.dump" : name
          end

          def fetch(uri:, output:, hops: 0)
            raise Hatchbox::Error, "Too many redirects fetching the backup." if hops > MAX_REDIRECTS

            Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 15, read_timeout: 300) do |http|
              http.request_get(uri.request_uri) do |response|
                return fetch(uri: URI.parse(response["location"]), output: output, hops: hops + 1) if response.is_a?(Net::HTTPRedirection)
                raise Hatchbox::Error, "Storage returned HTTP #{response.code} for the backup." unless response.is_a?(Net::HTTPSuccess)

                return save(response: response, output: output)
              end
            end
          end

          def save(response:, output:)
            written = 0
            File.open("#{output}.part", "wb") do |file|
              response.read_body do |chunk|
                file.write(chunk)
                written += chunk.bytesize
              end
            end
            File.rename("#{output}.part", output)
            written
          end

          def megabytes(bytes)
            format("%.1f MB", bytes / 1_048_576.0)
          end
        end
      end
    end
  end
end
