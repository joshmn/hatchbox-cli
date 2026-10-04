# frozen_string_literal: true

module Hatchbox
  module Commands
    module Releases
      class Output < Hatchbox::Command
        describe "releases:output",
          summary: "view the output of a release, following it while it runs",
          usage: "releases:output [RELEASE]",
          args: { release: "[RELEASE]" },
          aliases: ["builds:output"],
          help: [
            "RELEASE is an id from hatchbox releases, or deploy or restart for the latest one.",
            "Any Hatchbox log id works here, including ones from server and database activity."
          ]

        def call
          log_id = resolve_log(args.release)
          log = operation.fetch(log_id)
          return follow(log_id) unless Hatchbox::FINISHED.include?(log["state"].to_s)

          operation.print_log(log)
          log["state"] == "completed" ? 0 : 1
        end

        private

        def follow(log_id)
          operation.stream(log_id).ok? ? 0 : 1
        end
      end
    end
  end
end
