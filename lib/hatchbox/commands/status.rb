# frozen_string_literal: true

module Hatchbox
  module Commands
    class Status < Hatchbox::Command
      describe("status",
        summary: "show the latest deploy and its output")

      def call
        none!
        log = operation.fetch(resolve_log(nil, kind: Hatchbox::Activity::DEPLOY))
        ui.header("#{label} Deploy #{log["id"]}")
        Hatchbox::ReleaseSummary.show(log)
        puts
        return follow_deploy(log["id"]) unless Hatchbox::FINISHED.include?(log["state"].to_s)

        operation.print_log(log)
        log["state"] == "completed" ? 0 : 1
      end
    end
  end
end
