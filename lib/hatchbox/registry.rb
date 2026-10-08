# frozen_string_literal: true

module Hatchbox
  module Registry
    COMMANDS = {}
    ALIASES = {}
    SOURCES = {}
    CONFLICTS = []
    RESERVED = ["help", "commands", "version"].freeze
    NAME = /\A[a-z][a-z0-9_-]*(:[a-z][a-z0-9_-]*)*\z/.freeze

    class << self
      def add(klass)
        name = klass.meta[:name]
        return unless claim(name: name, klass: klass)

        COMMANDS[name] = klass
        SOURCES[klass] = source if source
        klass.meta[:aliases].each { |other| ALIASES[other] = name if claim(name: other, klass: klass) }
      end

      def loading(name)
        @source = name
        yield
      ensure
        @source = nil
      end

      def drop(name)
        COMMANDS.delete_if { |_command, klass| SOURCES[klass] == name }
        ALIASES.delete_if { |_alias, command| !COMMANDS.key?(command) }
        SOURCES.delete_if { |_klass, owner| owner == name }
        CONFLICTS.delete_if { |owner, _message| owner == name }
      end

      def source_of(klass)
        SOURCES[klass]
      end

      def from(name)
        COMMANDS.select { |_command, klass| SOURCES[klass] == name }.keys.sort
      end

      def conflicts(name = nil)
        CONFLICTS.select { |owner, _message| name.nil? || owner == name }.map { |_owner, message| message }
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

      private

      attr_reader :source

      def claim(name:, klass:)
        check!(name)
        taken = find(name)
        return true unless taken
        return false if taken == klass
        raise Hatchbox::Error, "#{name} is defined twice." unless source

        CONFLICTS << [source, "Skipped #{name} from #{source}, since #{source_of(taken) || "hatchbox"} already has it."]
        false
      end

      def check!(name)
        raise Hatchbox::Error, "#{name.inspect} can't be a command name. Use lowercase letters, numbers, - and _, with : between parts." unless name.is_a?(String) && name.match?(NAME)
        raise Hatchbox::Error, "#{name} is taken by hatchbox itself." if RESERVED.include?(name)
        raise Hatchbox::Error, "#{name} can't be a command name, since hatchbox reads it as #{canonical(name)}." unless canonical(name) == name
      end
    end
  end
end
