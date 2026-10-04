# frozen_string_literal: true

module Hatchbox
  class RemoteCommand
    class InvalidEnv < Hatchbox::Error; end

    ENV_NAME = /\A[A-Za-z_][A-Za-z0-9_]*\z/.freeze

    attr_reader :text

    def initialize(text:, env: [])
      @text = text
      @env = env
    end

    def rails?
      ["rails", "bin/rails"].include?(text) || text.start_with?("rails ", "bin/rails ")
    end

    def rails_exec
      "exec bin/rails #{text.sub(%r{\Abin/}, "").sub(/\Arails/, "").strip}"
    end

    def exports
      pairs = Array(env).flat_map { |entry| entry.split(";") }.map { |pair| pair.strip }.reject { |pair| pair.empty? }
      pairs.map { |pair| export(pair) }.join("\n")
    end

    private

    attr_reader :env

    def export(pair)
      name, separator, value = pair.partition("=")
      raise InvalidEnv, "#{pair} is invalid. --env takes KEY=VALUE pairs separated by semicolons." if separator.empty? || name !~ ENV_NAME

      "export #{name}=#{Shellwords.escape(value)}"
    end
  end
end
