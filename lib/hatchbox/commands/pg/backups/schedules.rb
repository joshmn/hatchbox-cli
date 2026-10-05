# frozen_string_literal: true

module Hatchbox
  module Commands
    module Pg
      module Backups
        class Schedules < Hatchbox::Command
          include Hatchbox::Commands::Pg::Backups::Tools

          describe "pg:backups:schedules",
            summary: "show the backup schedule of a database",
            args: { database: "[DATABASE]" },
            flags: [JSON_FLAG]

          def call
            record = one_database
            config = backup_configuration(record)
            return print_json(config) if json?

            ui.header("Backup Schedule for #{title_for(record)}")
            Hatchbox::BackupSchedule.show(config)
            0
          end
        end
      end
    end
  end
end
