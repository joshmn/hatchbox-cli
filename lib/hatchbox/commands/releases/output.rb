# frozen_string_literal: true

module Hatchbox
  module Commands
    module Releases
      class Output < Hatchbox::Command
        describe "releases:output",
          summary: "view the output of a release, following it while it runs",
          args: { release: "[RELEASE]" },
          aliases: ["builds:output"],
          help: [
            "RELEASE is an id from hatchbox releases, or deploy or restart for the latest",
            "one. Any Hatchbox log id works here, including ones from server and",
            "database activity."
          ]

        def call
          show_log(operation.fetch(resolve_log(args.release)))
        end
      end
    end
  end
end
