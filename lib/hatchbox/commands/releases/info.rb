# frozen_string_literal: true

module Hatchbox
  module Commands
    module Releases
      class Info < Hatchbox::Command
        describe "releases:info",
          summary: "view detailed information for a release",
          args: { release: "[RELEASE]" },
          flags: [JSON_FLAG],
          help: ["RELEASE is an id from hatchbox releases, or deploy or restart for the latest one. It defaults to the latest release."]

        def call
          log = operation.fetch(resolve_log(args.release))
          return print_json(log) if json?

          ui.header("Release #{log["id"]}")
          Hatchbox::ReleaseSummary.show(log)
          0
        end
      end
    end
  end
end
