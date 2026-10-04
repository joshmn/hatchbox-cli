# frozen_string_literal: true

module Hatchbox
  class ArgumentParser
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
      flags.each do |short, long, _description, type|
        key = key_for(long)
        spec = [short, long, type == :many ? nil : type].compact
        negated = long.start_with?("--no-")
        parser.on(*spec) { |value| store(key: key, value: value, many: type == :many, negated: negated) }
      end
      parser
    end

    def store(key:, value:, many:, negated:)
      if many
        (options[key] ||= []) << value
      else
        options[key] = negated ? true : value
      end
    end

    def key_for(long)
      long.sub(/\A--(\[no-\])?/, "").split(/[ =]/).first.tr("-", "_").to_sym
    end
  end
end
