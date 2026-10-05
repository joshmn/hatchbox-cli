# frozen_string_literal: true

module Hatchbox
  module Commands
    module Pg
      module Backups
        class Unschedule < Hatchbox::Command
          include Hatchbox::Commands::Pg::Backups::Tools

          describe "pg:backups:unschedule",
            summary: "stop backups",
            args: { database: "[DATABASE]" },
            flags: [[nil, "--confirm DATABASE", "the database's name, to skip the prompt"]]

          def call
            record = one_database
            confirm(expected: record["name"].to_s, lines: ["This command will stop backups of #{record["name"]}."])
            data = client.delete("/databases/#{record["id"]}/backup_configuration").json || {}
            message = "Unscheduling backups of #{title_for(record)} (#{record["name"]})"
            queued_or_done(message: message, log_id: data["log_id"], status: "done, they were already off")
          end
        end
      end
    end
  end
end
