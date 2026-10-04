# frozen_string_literal: true

module Hatchbox
  module ReleaseSummary
    class << self
      def show(log)
        Hatchbox::Printer.styled_hash([
          ["Change", Hatchbox::Activity.change(log)],
          ["By", log["username"]],
          ["When", Hatchbox::Formatter.date(log["created_at"])],
          ["State", log["state"]],
          ["Commit", log["commit_sha"]],
          ["Started", Hatchbox::Formatter.date(log["started_at"])],
          ["Completed", Hatchbox::Formatter.date(log["completed_at"])],
          ["Duration", Hatchbox::Formatter.duration(from: log["started_at"], to: log["completed_at"])],
          ["Servers", (log["child_logs"] || []).map { |child| "#{child["loggable_id"]} #{child["state"]}" }]
        ])
      end
    end
  end
end
