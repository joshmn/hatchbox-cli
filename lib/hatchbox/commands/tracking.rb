# frozen_string_literal: true

module Hatchbox
  module Commands
    module Tracking
      private

      def operation
        @operation ||= Hatchbox::Operation.new(client: client, app: log_app)
      end

      def log_app
        return nil unless meta[:app]

        app
      rescue Hatchbox::Error
        nil
      end

      def queued(message:, log_id:, gone_ok: false)
        raise Hatchbox::Error, "Hatchbox accepted it but returned no log id." if Hatchbox.blank?(log_id)
        return done(message: message, status: "done, queued as #{log_id}") if options.fetch(:no_wait)

        result = nil
        ui.action(message) do |step|
          result = operation.wait(log_id, gone_ok: gone_ok)
          step.status = status_for(result)
        end
        return 0 if result.ok?

        operation.report_failure(result)
        1
      end

      def queued_or_done(message:, log_id:, status: "done")
        return queued(message: message, log_id: log_id) unless Hatchbox.blank?(log_id)

        done(message: message, status: status)
      end

      def done(message:, status: "done")
        ui.action(message) { |step| step.status = status }
        0
      end

      def follow_deploy(log_id)
        result = operation.stream(log_id)
        $stdout.puts
        ui.action("Verifying deploy") { |step| step.status = status_for(result) }
        return 0 if result.ok?

        ui.error("The deploy #{result.state}. Read it again with hatchbox releases:output #{log_id}")
        1
      end

      def status_for(result)
        result.ok? ? "done" : ui.paint(result.state.to_s, code: 31)
      end

      def resolve_log(wanted, kind: nil)
        Hatchbox::LogResolver.new(client: client, app_id: app_id, label: label).resolve(wanted, kind: kind)
      end
    end
  end
end
