# frozen_string_literal: true

module Hatchbox
  module Commands
    module Ps
      class Create < Hatchbox::Command
        include Hatchbox::Commands::Ps::Fields

        describe "ps:create",
          summary: "add a process to the app",
          usage: "ps:create NAME --start COMMAND (--roles LIST | --server SERVER)",
          args: { name: "[NAME]" },
          flags: Hatchbox::Commands::Ps::Fields::FLAGS + [WAIT_FLAG],
          examples: ["$ hatchbox ps:create worker --start 'bundle exec sidekiq' --roles worker", "Creating worker on fpd... done"]

        def call
          body = process_body
          body["name"] = args.name if args.name && Hatchbox.blank?(body["name"])
          usage_error("Must specify NAME.") if Hatchbox.blank?(body["name"])
          usage_error("Must specify --start, the command that runs.") if Hatchbox.blank?(body["start_command"])
          usage_error("Must specify --roles or --server, so Hatchbox knows where to run it.") if Array(body["roles"]).empty? && Hatchbox.blank?(body["server_id"])
          Hatchbox.check_name!(body["name"])

          data = client.post("/apps/#{app_id}/processes", body: { "process" => body }).json || {}
          code = Hatchbox.blank?(data["log_id"]) ? 0 : queued(message: "Creating #{body["name"]} on #{label}", log_id: data["log_id"])
          show(data)
          code
        end
      end
    end
  end
end
