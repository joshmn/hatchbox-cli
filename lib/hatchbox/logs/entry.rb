# frozen_string_literal: true

module Hatchbox
  module Logs
    class Entry
      attr_reader :time, :source, :label, :message, :color, :order

      def initialize(time:, source:, label:, message:, color:, order:)
        @time = time
        @source = source
        @label = label
        @message = message
        @color = color
        @order = order
      end

      def line(colors:)
        tag = "#{source}[#{label}]:"
        tag = "\e[#{color}m#{tag}\e[0m" if colors
        "#{time.strftime("%Y-%m-%dT%H:%M:%S.%6N+00:00")} #{tag} #{message}"
      end
    end
  end
end
