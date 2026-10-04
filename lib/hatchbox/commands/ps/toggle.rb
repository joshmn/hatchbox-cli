# frozen_string_literal: true

module Hatchbox
  module Commands
    module Ps
      module Toggle
        private

        def toggled_process
          app.formation.find_process(args.type)
        end

        def toggled(data:, message:, already:)
          log_id = data["log_id"]
          return queued(message: message, log_id: log_id) unless Hatchbox.blank?(log_id)

          ui.action(message) { |step| step.status = "done, #{already}" }
          0
        end
      end
    end
  end
end
