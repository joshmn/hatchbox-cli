# frozen_string_literal: true

module Hatchbox
  module Commands
    module Cron
      class List < Hatchbox::Command
        include Hatchbox::Commands::Cron::Fields

        describe "cron",
          summary: "list the app's cron jobs",
          aliases: ["cron:list"],
          flags: [JSON_FLAG],
          help: [
            "Cron jobs run from the app's current release as the deploy user, on every server",
            "in the cluster carrying the cron role. Cron keeps none of their output; read when",
            "they ran with hatchbox run 'journalctl -u cron'."
          ]

        def call
          rows = cron_jobs
          return print_json(rows) if json?

          ui.header("#{label} Cron Jobs")
          return puts("No cron jobs on #{label}.") if rows.empty?

          printer.table(rows: rows, columns: [
            ["Id", ->(row) { row["id"] }],
            ["Name", ->(row) { row["name"] }],
            ["Schedule", ->(row) { row["run_at"] }],
            ["Command", ->(row) { row["command"] }]
          ])
          0
        end
      end
    end
  end
end
