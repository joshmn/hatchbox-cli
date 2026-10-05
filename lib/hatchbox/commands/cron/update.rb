# frozen_string_literal: true

module Hatchbox
  module Commands
    module Cron
      class Update < Hatchbox::Command
        include Hatchbox::Commands::Cron::Fields

        describe "cron:update",
          summary: "change a cron job",
          args: { job: "JOB" },
          flags: Hatchbox::Commands::Cron::Fields::FLAGS + [[nil, "--command COMMAND", "the command to run"]]

        def call
          row = find_job(args.job)
          body = cron_body
          body["command"] = options.command if options.key?(:command)
          usage_error("Nothing to change. See hatchbox help cron:update.") if body.empty?

          updated = nil
          ui.action("Updating #{row["name"]} on #{label}") { updated = client.patch("/apps/#{app_id}/cron_jobs/#{row["id"]}", body: { "cron_job" => body }).json || {} }
          show(updated)
          0
        end
      end
    end
  end
end
