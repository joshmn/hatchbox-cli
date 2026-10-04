# frozen_string_literal: true

module Hatchbox
  module Formatter
    class << self
      def date(value)
        time = parse_time(value)
        return nil unless time

        "#{time.localtime.strftime("%Y/%m/%d %H:%M:%S %z")} (~ #{ago(time)})"
      end

      def short_date(value)
        time = parse_time(value)
        time ? time.localtime.strftime("%Y/%m/%d %H:%M:%S %z") : ""
      end

      def ago(time)
        seconds = [(Time.now - time).to_i, 0].max
        return "#{seconds}s ago" if seconds < 60
        return "#{seconds / 60}m ago" if seconds < 3600
        return "#{seconds / 3600}h ago" if seconds < 86_400

        "#{seconds / 86_400}d ago"
      end

      def duration(from:, to:)
        start = parse_time(from)
        finish = parse_time(to)
        return nil unless start && finish

        seconds = [(finish - start).to_i, 0].max
        return "#{seconds}s" if seconds < 60

        "#{seconds / 60}m #{seconds % 60}s"
      end

      def parse_time(value)
        return nil if Hatchbox.blank?(value)

        Time.iso8601(value.to_s)
      rescue ArgumentError
        nil
      end

      def list(words)
        items = words.map { |word| word.to_s }
        return items.first.to_s if items.length < 2

        "#{items[0..-2].join(", ")} and #{items.last}"
      end

      def plural(count:, word:)
        "#{count} #{word}#{count == 1 ? "" : "s"}"
      end

      def yes_no(value)
        value ? "on" : "off"
      end
    end
  end
end
