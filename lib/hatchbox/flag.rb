# frozen_string_literal: true

module Hatchbox
  class Flag
    attr_reader :short, :long, :description, :type

    def initialize(spec)
      @short, @long, @description, @type = spec
    end

    def key
      long.sub(/\A--(\[no-\])?/, "").split(/[ =]/).first.tr("-", "_").to_sym
    end

    def many?
      type == :many
    end

    def negated?
      long.start_with?("--no-")
    end

    def switch
      [short, long, many? ? nil : type].compact
    end

    def global?
      ([short, long.split(/[ =]/).first] & Hatchbox::GlobalFlags::SWITCHES).any?
    end

    def label
      short ? "#{short}, #{long}" : "    #{long}"
    end
  end
end
