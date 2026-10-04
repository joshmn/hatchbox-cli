# frozen_string_literal: true

module Hatchbox
  class Progress
    def initialize(operation:, no_wait:)
      @operation = operation
      @no_wait = no_wait
    end

    def queued(message:, log_id:, gone_ok: false)
      raise Hatchbox::Error, "Hatchbox accepted it but returned no log id." if Hatchbox.blank?(log_id)

      if no_wait
        Hatchbox::Ui.action(message) { |step| step.status = "done, queued as #{log_id}" }
        return 0
      end

      result = nil
      Hatchbox::Ui.action(message) do |step|
        result = operation.wait(log_id, gone_ok: gone_ok)
        step.status = status_for(result)
      end
      return 0 if result.ok?

      operation.report_failure(result)
      1
    end

    def follow_deploy(log_id)
      result = operation.stream(log_id)
      $stdout.puts
      Hatchbox::Ui.action("Verifying deploy") { |step| step.status = status_for(result) }
      return 0 if result.ok?

      Hatchbox::Ui.error("The deploy #{result.state}. Read it again with hatchbox releases:output #{log_id}")
      1
    end

    private

    attr_reader :operation, :no_wait

    def status_for(result)
      result.ok? ? "done" : Hatchbox::Ui.paint(result.state.to_s, code: 31)
    end
  end
end
