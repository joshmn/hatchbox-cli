# frozen_string_literal: true

module Hatchbox
  module Commands
    module Cron
      module Fields
        FLAGS = [
          [nil, "--at SCHEDULE", "cron expression or @hourly, @daily, @weekly, @monthly"],
          [nil, "--name NAME", "a label for the job"],
          [nil, "--[no-]appsignal", "wrap it in AppSignal cron monitoring"],
          [nil, "--honeybadger-checkin-id ID", "Honeybadger check-in to report to, or an empty string to stop"]
        ].freeze

        MAP = {
          at: "run_at",
          name: "name",
          appsignal: "appsignal",
          honeybadger_checkin_id: "honeybadger_checkin_id"
        }.freeze

        private

        def cron_jobs
          client.get("/apps/#{app_id}/cron_jobs").json || []
        end

        def find_job(wanted)
          rows = cron_jobs
          found = rows.find { |row| row["id"].to_s == wanted.to_s }
          named = rows.select { |row| row["name"].to_s.casecmp?(wanted.to_s) }
          found = named.first if found.nil? && named.length == 1
          raise Hatchbox::Error, "No cron job #{wanted}. hatchbox cron lists them." unless found

          found
        end

        def cron_body
          body = options.fields_for(MAP)
          body["honeybadger_checkin_id"] = nil if body["honeybadger_checkin_id"] == ""
          body
        end

        def show(row)
          printer.styled_hash([
            ["Id", row["id"].to_s],
            ["Name", row["name"]],
            ["Schedule", row["run_at"]],
            ["Command", row["command"]],
            ["AppSignal", row["appsignal"] ? "on" : nil],
            ["Honeybadger", row["honeybadger_checkin_id"]],
            ["Created", formatter.date(row["created_at"])],
            ["Updated", formatter.date(row["updated_at"])]
          ])
        end
      end
    end
  end
end
