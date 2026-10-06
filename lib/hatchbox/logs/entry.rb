# frozen_string_literal: true

module Hatchbox
  module Logs
    Entry = Struct.new(:time, :source, :label, :message, :color, :order, keyword_init: true) do
      def line(colors:)
        tag = Hatchbox::Color.paint("#{source}[#{label}]:", code: color, force: colors)
        "#{time.strftime("%Y-%m-%dT%H:%M:%S.%6N+00:00")} #{tag} #{message}"
      end
    end
  end
end
