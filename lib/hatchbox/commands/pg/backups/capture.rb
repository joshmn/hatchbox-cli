# frozen_string_literal: true

module Hatchbox
  module Commands
    module Pg
      module Backups
        class Capture < Hatchbox::Command
          include Hatchbox::Commands::Pg::Backups::Tools

          describe("pg:backups:capture",
            summary: "take a backup now",
            usage: "pg:backups:capture [DATABASE]",
            flags: [WAIT_FLAG],
            help: ["Backups have to be scheduled first, with hatchbox pg:backups:schedule, since that is where they are stored."])

          def call
            record = one_database
            log_id = (client.post("/databases/#{record["id"]}/backups").json || {})["id"]
            queued(message: "Backing up #{title_for(record)} (#{record["name"]})", log_id: log_id)
          end
        end
      end
    end
  end
end
