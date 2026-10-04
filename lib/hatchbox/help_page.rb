# frozen_string_literal: true

module Hatchbox
  module HelpPage
    class << self
      def topic(topic:, command:)
        if command
          usage(command)
        else
          puts("Usage: hatchbox #{topic}:COMMAND")
          puts
          puts(" #{Hatchbox::Help.blurb(topic)}") if Hatchbox::Help.blurb(topic)
        end
        others = Hatchbox::Help.members(topic).reject { |klass| klass == command }
        return if others.empty?

        puts
        puts("Additional commands, type \"hatchbox help COMMAND\" for more details:")
        puts
        width = others.map { |klass| klass.meta[:usage].length }.max
        others.each { |klass| puts("  #{klass.meta[:usage].ljust(width)}  #  #{klass.meta[:summary]}") }
      end

      def command(command)
        usage(command)
        meta = command.meta
        lines(Array(meta[:help])) if meta[:help]
        if meta[:aliases].any?
          puts
          puts("Aliases: #{meta[:aliases].join(", ")}")
        end
        return if meta[:examples].empty?

        puts
        puts("Examples:")
        lines(meta[:examples])
      end

      private

      def usage(command)
        meta = command.meta
        puts("Usage: hatchbox #{meta[:usage]}")
        puts
        puts(" #{meta[:summary]}")
        flags = (meta[:app] ? Hatchbox::Command::APP_FLAGS : []) + meta[:flags]
        return if flags.empty?

        puts
        labels = flags.map { |short, long, _description, _type| short ? "#{short}, #{long}" : "    #{long}" }
        width = labels.map { |text| text.length }.max
        flags.each_with_index { |(_short, _long, description, _type), index| puts(" #{labels[index].ljust(width)}  #  #{description}") }
      end

      def lines(texts)
        puts
        texts.each { |line| puts(" #{line}".rstrip) }
      end
    end
  end
end
