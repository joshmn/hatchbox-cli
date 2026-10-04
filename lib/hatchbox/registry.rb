# frozen_string_literal: true

module Hatchbox
  module Registry
    COMMANDS = {}
    ALIASES = {}

    class << self
      def add(klass)
        COMMANDS[klass.meta[:name]] = klass
        klass.meta[:aliases].each { |name| ALIASES[name] = klass.meta[:name] }
      end

      def find(name)
        key = canonical(name)
        COMMANDS[key] || COMMANDS[ALIASES[key]]
      end

      def canonical(name)
        name.to_s.sub(/\Apostgresql(?=:|\z)/, "pg")
      end

      def names
        COMMANDS.keys + ALIASES.keys
      end

      def visible
        COMMANDS.values.reject { |klass| klass.meta[:hidden] }
      end

      def suggest(name)
        best = names.min_by { |candidate| distance(left: name, right: candidate) }
        return nil unless best

        distance(left: name, right: best) <= [name.length / 2, 3].max ? best : nil
      end

      private

      def distance(left:, right:)
        rows = (0..right.length).to_a
        left.each_char.with_index(1) do |char, i|
          previous = rows[0]
          rows[0] = i
          right.each_char.with_index(1) do |other, j|
            current = rows[j]
            rows[j] = [rows[j] + 1, rows[j - 1] + 1, previous + (char == other ? 0 : 1)].min
            previous = current
          end
        end
        rows[right.length]
      end
    end
  end
end
