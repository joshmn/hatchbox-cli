# frozen_string_literal: true

module Hatchbox
  module Commands
    module Ps
      class Update < Hatchbox::Command
        include Hatchbox::Commands::Ps::Fields

        describe "ps:update",
          summary: "change a process",
          usage: "ps:update TYPE [--start COMMAND] [--roles LIST] ...",
          args: { type: "TYPE" },
          flags: Hatchbox::Commands::Ps::Fields::FLAGS + [WAIT_FLAG],
          examples: ["$ hatchbox ps:update worker --start 'bundle exec sidekiq -c 10'", "Updating worker on fpd... done"]

        def call
          process = app.formation.find_process(args.type)
          body = process_body
          usage_error("Nothing to change. See hatchbox help ps:update.") if body.empty?

          message = "Updating #{process["name"]} on #{label}"
          data = client.patch("/apps/#{app_id}/processes/#{process["id"]}", body: { "process" => body }).json || {}
          queued_or_done(message: message, log_id: data["log_id"])
        end
      end
    end
  end
end
