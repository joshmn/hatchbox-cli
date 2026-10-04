# frozen_string_literal: true

module Hatchbox
  class Operation
    class Result
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
end
