# frozen_string_literal: true

module Hatchbox
  class OperationResult
    attr_reader :log, :state, :gone

    def initialize(log:, state:, gone:)
      @log = log
      @state = state
      @gone = gone
    end

    def ok?
      gone || state == "completed"
    end
  end
end
