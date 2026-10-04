# frozen_string_literal: true

module Hatchbox
  module Logs
    class Entry
      attr_reader :time, :source, :dyno, :message, :color, :order

      def initialize(time:, source:, dyno:, message:, color:, order:)
        @time = time
        @source = source
        @dyno = dyno
        @message = message
        @color = color
        @order = order
      end

      def line(colors:)
        label = "#{source}[#{dyno}]:"
        label = "\e[#{color}m#{label}\e[0m" if colors
        "#{time.strftime("%Y-%m-%dT%H:%M:%S.%6N+00:00")} #{label} #{message}"
      end
    end
  end
end
