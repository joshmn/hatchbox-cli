# frozen_string_literal: true

module Hatchbox
  module Commands
    module Cron
      class Add < Hatchbox::Command
        include Hatchbox::Commands::Cron::Fields

        describe "cron:add",
          summary: "add a cron job",
          usage: "cron:add COMMAND --at SCHEDULE",
          args: { command: "[COMMAND...]" },
          aliases: ["cron:create"],
          lenient: true,
          flags: Hatchbox::Commands::Cron::Fields::FLAGS,
          help: ["The name defaults to the command. Flags meant for the command go after --."],
          examples: ["$ hatchbox cron:add bin/rails sync:nightly --at '0 0 * * *' --name 'Nightly sync'", "Adding Nightly sync to fpd... done"]

        def call
          command = (args.command + passthru).join(" ")
          usage_error("Must specify COMMAND.") if command.strip.empty?

          body = cron_body.merge("command" => command)
          usage_error("Must specify --at, when it runs.") if Hatchbox.blank?(body["run_at"])
          body["name"] = command if Hatchbox.blank?(body["name"])
          row = ui.action("Adding #{body["name"]} to #{label}") { client.post("/apps/#{app_id}/cron_jobs", body: { "cron_job" => body }).json || {} }
          show(row)
          0
        end
      end
    end
  end
end
