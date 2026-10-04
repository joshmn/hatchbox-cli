# frozen_string_literal: true

module Hatchbox
  class GlobalFlags
    attr_reader :app, :remote, :rest

    def initialize(argv)
      @argv = argv
      @rest = []
    end

    def parse
      tokens = argv.dup
      until tokens.empty?
        token = tokens.shift
        if token == "--"
          rest << token
          rest.concat(tokens)
          break
        end

        take(token: token, tokens: tokens)
      end
      self
    end

    def help?
      @help == true
    end

    def version?
      @version == true
    end

    private

    attr_reader :argv

    def take(token:, tokens:)
      case token
      when "-a", "--app" then @app = value(flag: token, tokens: tokens)
      when /\A--app=(.*)\z/ then @app = Regexp.last_match(1)
      when /\A-a(.+)\z/ then @app = Regexp.last_match(1)
      when "-r", "--remote" then @remote = value(flag: token, tokens: tokens)
      when /\A--remote=(.*)\z/ then @remote = Regexp.last_match(1)
      when /\A-r(.+)\z/ then @remote = Regexp.last_match(1)
      when "-h", "--help" then @help = true
      when "--version" then @version = true
      when "-v" then short_v(token)
      else rest << token
      end
    end

    def short_v(token)
      return rest << token if rest.any?

      @version = true
    end

    def value(flag:, tokens:)
      found = tokens.shift
      raise Hatchbox::Error, "Flag #{flag} expects a value." if found.nil? || found == "--"

      found
    end
  end
end
