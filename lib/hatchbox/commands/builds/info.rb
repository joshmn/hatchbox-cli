# frozen_string_literal: true

module Hatchbox
  module Commands
    module Builds
      class Info < Hatchbox::Command
        describe("builds:info",
          summary: "view detailed information for a build",
          usage: "builds:info [BUILD]",
          flags: [JSON_FLAG])

        def call
          usage_error("One build at a time.") if positionals.length > 1
          log = operation.fetch(resolve_log(positionals.first, kind: Hatchbox::Activity::DEPLOY))
          return print_json(log) if json?

          ui.header("Build #{log["id"]}")
          Hatchbox::ReleaseSummary.show(log)
          0
        end
      end
    end
  end
end
