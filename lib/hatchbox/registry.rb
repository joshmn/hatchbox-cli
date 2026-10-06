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

      def commands
        COMMANDS.values
      end

      def suggest(name)
        return nil unless defined?(DidYouMean::SpellChecker)

        DidYouMean::SpellChecker.new(dictionary: names).correct(name.to_s).first
      end
    end
  end
end
