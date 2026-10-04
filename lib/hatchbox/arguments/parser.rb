# frozen_string_literal: true

module Hatchbox
  class Arguments
    class Parser
      attr_reader :options, :positionals, :passthru

      def initialize(flags:, lenient:)
        @flags = flags
        @lenient = lenient
      end

      def parse(args)
        @options = {}
        @positionals = []
        cut = args.index("--")
        head = cut ? args[0, cut] : args.dup
        @passthru = cut ? args[(cut + 1)..-1] : []
        consume(head)
        self
      rescue OptionParser::MissingArgument => e
        raise Hatchbox::Error, "Flag #{e.args.join(" ")} expects a value."
      rescue OptionParser::ParseError => e
        raise Hatchbox::Error, "#{e.message[0].upcase}#{e.message[1..-1]}."
      end

      private

      attr_reader :flags, :lenient

      def consume(head)
        parser = build
        until head.empty?
          begin
            parser.order!(head) { |arg| positionals << arg }
          rescue OptionParser::InvalidOption => e
            raise Hatchbox::Error, "Unexpected argument: #{e.args.join(" ")}\nSee more help with --help" unless lenient

            positionals.concat(e.args)
          end
        end
      end

      def build
        parser = OptionParser.new
        parser.require_exact = true
        flags.each { |flag| parser.on(*flag.switch) { |value| store(flag: flag, value: value) } }
        parser
      end

      def store(flag:, value:)
        return (options[flag.key] ||= []) << value if flag.many?

        options[flag.key] = flag.negated? ? true : value
      end
    end
  end
end
