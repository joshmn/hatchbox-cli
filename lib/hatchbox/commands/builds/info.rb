# frozen_string_literal: true

module Hatchbox
  module Commands
    module Builds
      class Info < Hatchbox::Command
        describe "builds:info",
          summary: "view detailed information for a build",
          args: { build: "[BUILD]" },
          flags: [JSON_FLAG]

        def call
          log = operation.fetch(resolve_log(args.build, kind: Hatchbox::Activity::DEPLOY))
          return print_json(log) if json?

          ui.header("Build #{log["id"]}")
          Hatchbox::ReleaseSummary.show(log)
          0
        end
      end
    end
  end
end
