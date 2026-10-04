# frozen_string_literal: true

module Hatchbox
  module Commands
    module Pg
      module Backups
        class Test < Hatchbox::Command
          include Hatchbox::Commands::Pg::Backups::Tools

          describe "pg:backups:test",
            summary: "upload a test file to the backup storage",
            usage: "pg:backups:test [DATABASE]",
            args: { database: "[DATABASE]" }

          def call
            record = one_database
            log_id = (client.post("/databases/#{record["id"]}/backups/test_connection").json || {})["id"]
            result = nil
            ui.action("Testing backup storage for #{record["name"]}") do |step|
              result = operation.wait(log_id)
              step.status = result.ok? ? "done" : ui.paint(result.state.to_s, code: 31)
            end
            operation.print_log(result.log || {})
            result.ok? ? 0 : 1
          end
        end
      end
    end
  end
end
