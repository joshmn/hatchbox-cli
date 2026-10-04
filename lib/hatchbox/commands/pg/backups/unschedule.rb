# frozen_string_literal: true

module Hatchbox
  module Commands
    module Pg
      module Backups
        class Unschedule < Hatchbox::Command
          include Hatchbox::Commands::Pg::Backups::Tools

          describe("pg:backups:unschedule",
            summary: "stop backups and clear the storage settings",
            usage: "pg:backups:unschedule [DATABASE]",
            flags: [[nil, "--confirm DATABASE", "the database's name, to skip the prompt"]],
            help: ["Hatchbox clears the provider, bucket and credentials when backups are turned off, so turning them back on means passing those again."])

          def call
            record = one_database
            confirm(expected: record["name"].to_s, lines: ["This command stops backups of #{record["name"]} and clears its storage settings and credentials."])
            data = client.delete("/databases/#{record["id"]}/backup_configuration").json || {}
            message = "Unscheduling backups of #{title_for(record)} (#{record["name"]})"
            return queued(message: message, log_id: data["log_id"]) unless Hatchbox.blank?(data["log_id"])

            ui.action(message) { |step| step.status = "done, they were already off" }
            0
          end
        end
      end
    end
  end
end
