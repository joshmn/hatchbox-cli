# frozen_string_literal: true

module Hatchbox
  module ConfigLine
    class << self
      def key(line)
        text = line.strip
        return nil if text.start_with?("#") || !text.include?("=")

        text.split("=", 2).first.strip
      end

      def remote(line)
        text = line.strip
        return nil if text.empty? || text.start_with?("#") || text.include?("=")

        app, _colon, env = text.rpartition(":")
        return nil if app.strip.empty? || env.strip.empty?

        [env.strip, app.strip]
      end
    end
  end
end
