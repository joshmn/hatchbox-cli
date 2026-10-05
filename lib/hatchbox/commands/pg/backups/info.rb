# frozen_string_literal: true

module Hatchbox
  module Commands
    module Pg
      module Backups
        class Info < Hatchbox::Command
          include Hatchbox::Commands::Pg::Backups::Tools

          describe "pg:backups:info",
            summary: "show the output of a backup",
            args: { backup: "[BACKUP_ID]" },
            flags: [["-d", "--database DATABASE", "which database, when the app has more than one"]],
            help: ["Without BACKUP_ID, shows the most recent backup."]

          def call
            log_id = args.backup
            log_id = latest_id if Hatchbox.blank?(log_id)
            log = operation.fetch(log_id)
            ui.header("Backup #{log["id"]}")
            Hatchbox::ReleaseSummary.show(log)
            puts
            operation.print_log(log)
            log["state"] == "completed" ? 0 : 1
          end

          private

          def latest_id
            latest = backup_logs(backed_up(options.database)).first
            raise Hatchbox::Error, "No backups on record." unless latest

            latest["id"]
          end
        end
      end
    end
  end
end
