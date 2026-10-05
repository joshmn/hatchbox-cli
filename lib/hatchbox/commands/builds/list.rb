# frozen_string_literal: true

module Hatchbox
  module Commands
    module Builds
      class List < Hatchbox::Command
        MAX_PAGES = 10

        describe "builds",
          summary: "list the app's deploys",
          flags: [["-n", "--num NUM", "number of builds to display", Integer], JSON_FLAG]

        def call
          rows = deploys(options.num || 15)
          return print_json(rows) if json?

          ui.header("#{label} Builds")
          return puts("No builds on record.") if rows.empty?

          printer.columns(rows.map { |row| columns(row) })
          0
        end

        private

        def deploys(limit)
          client.pages("/apps/#{app_id}/logs?limit=100")
            .lazy
            .take(MAX_PAGES)
            .flat_map { |rows| rows.select { |row| Hatchbox::Activity.deploy?(row) } }
            .first(limit)
        end

        def columns(row)
          [
            row["id"].to_s,
            Hatchbox::Activity.state(row, completed: color.green("succeeded")),
            row["commit_sha"].to_s[0, 7],
            row["username"].to_s,
            formatter.date(row["created_at"]).to_s,
            row["description"].to_s.split("\n").first.to_s[0, 50]
          ]
        end
      end
    end
  end
end
