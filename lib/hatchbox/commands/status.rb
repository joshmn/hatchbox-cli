# frozen_string_literal: true

module Hatchbox
  module Commands
    class Status < Hatchbox::Command
      describe "status",
        summary: "show the latest deploy and its output"

      def call
        log = operation.fetch(resolve_log(nil, kind: Hatchbox::Activity::DEPLOY))
        ui.header("#{label} deploy #{log["id"]}")
        Hatchbox::ReleaseSummary.show(log)
        puts
        show_log(log, deploy: true)
      end
    end
  end
end
