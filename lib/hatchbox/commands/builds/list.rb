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
          rows = []
          url = "/apps/#{app_id}/logs?limit=100"
          pages = 0
          while url && rows.length < limit && pages < MAX_PAGES
            response = client.get(url)
            rows.concat(Array(response.json).select { |row| Hatchbox::Activity.deploy?(row) })
            url = response.next_page
            pages += 1
          end
          rows.first(limit)
        end

        def columns(row)
          [
            row["id"].to_s,
            painted(row["state"].to_s),
            row["commit_sha"].to_s[0, 7],
            row["username"].to_s,
            formatter.date(row["created_at"]).to_s,
            row["description"].to_s.split("\n").first.to_s[0, 50]
          ]
        end

        def painted(state)
          return color.green("succeeded") if state == "completed"
          return color.red(state) if ["failed", "aborted"].include?(state)

          color.yellow(state)
        end
      end
    end
  end
end
