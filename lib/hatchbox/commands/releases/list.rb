# frozen_string_literal: true

module Hatchbox
  module Commands
    module Releases
      class List < Hatchbox::Command
        describe "releases",
          summary: "display the app's release history",
          flags: [["-n", "--num NUM", "number of releases to display", Integer], [nil, "--page PAGE", "page of older releases", Integer], JSON_FLAG],
          help: [
            "Everything Hatchbox did to the app: deploys, restarts and process changes, each",
            "with the id hatchbox releases:output reads."
          ]

        def call
          limit = options.num || 15
          rows = client.get("/apps/#{app_id}/logs?page=#{options.page || 1}&limit=#{limit}").json || []
          return print_json(rows) if json?

          current = rows.find { |row| Hatchbox::Activity.deploy?(row) && row["state"] == "completed" }
          ui.header("#{label} Releases#{current ? " - Current: #{current["id"]}" : ""}")
          return puts("No releases on record.") if rows.empty?

          puts
          printer.columns(Hatchbox::Activity.rows(rows))
          0
        end
      end
    end
  end
end
