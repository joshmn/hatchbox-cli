# frozen_string_literal: true

module Hatchbox
  module Commands
    module Pg
      module Backups
        class List < Hatchbox::Command
          include Hatchbox::Commands::Pg::Backups::Tools

          describe "pg:backups",
            summary: "list database backups and the backup schedule",
            args: { database: "[DATABASE]" },
            flags: [JSON_FLAG],
            help: [
              "DATABASE defaults to the app's PostgreSQL database. Backups work on any",
              "unmanaged database Hatchbox runs; managed ones are backed up by your provider."
            ]

          def call
            record = one_database
            rows = backup_logs(record)
            config = backup_configuration(record)
            return print_json("backups" => rows, "schedule" => config) if json?

            ui.header("Backups of #{title_for(record)}")
            if rows.empty?
              puts("No backups on record.")
            else
              table(rows)
            end
            puts
            ui.header("Backup Schedule")
            Hatchbox::BackupSchedule.show(config)
            0
          end

          private

          def table(rows)
            printer.table(rows: rows, columns: [
              ["Id", ->(row) { row["id"] }],
              ["Created At", ->(row) { formatter.short_date(row["created_at"]) }],
              ["Status", ->(row) { row["state"] == "completed" ? "Completed" : row["state"].to_s.capitalize }],
              ["Duration", ->(row) { formatter.duration(from: row["started_at"], to: row["completed_at"]) }],
              ["By", ->(row) { row["username"] || "schedule" }]
            ])
          end
        end
      end
    end
  end
end
