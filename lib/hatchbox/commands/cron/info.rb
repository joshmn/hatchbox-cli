# frozen_string_literal: true

module Hatchbox
  module Commands
    module Cron
      class Info < Hatchbox::Command
        include Hatchbox::Commands::Cron::Fields

        describe "cron:info",
          summary: "show a cron job",
          args: { job: "JOB" },
          flags: [JSON_FLAG]

        def call
          row = find_job(args.job)
          return print_json(row) if json?

          ui.header(row["name"].to_s)
          show(row)
          0
        end
      end
    end
  end
end
