# frozen_string_literal: true

module Hatchbox
  module Commands
    module Cron
      class Remove < Hatchbox::Command
        include Hatchbox::Commands::Cron::Fields

        describe "cron:remove",
          summary: "remove a cron job",
          args: { job: "JOB" },
          aliases: ["cron:destroy", "cron:delete"]

        def call
          row = find_job(args.job)
          ui.action("Removing #{row["name"]} from #{label}") { client.delete("/apps/#{app_id}/cron_jobs/#{row["id"]}") }
          0
        end
      end
    end
  end
end
