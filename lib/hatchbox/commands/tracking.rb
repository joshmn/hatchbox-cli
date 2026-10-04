# frozen_string_literal: true

module Hatchbox
  module Commands
    module Tracking
      private

      def operation
        @operation ||= Hatchbox::Operation.new(client: client, app: meta[:app] ? app : nil)
      end

      def progress
        Hatchbox::Progress.new(operation: operation, no_wait: options.fetch(:no_wait))
      end

      def queued(message:, log_id:, gone_ok: false)
        progress.queued(message: message, log_id: log_id, gone_ok: gone_ok)
      end

      def follow_deploy(log_id)
        progress.follow_deploy(log_id)
      end

      def resolve_log(wanted, kind: nil)
        Hatchbox::LogResolver.new(client: client, app_id: app_id, label: label).resolve(wanted, kind: kind)
      end
    end
  end
end
