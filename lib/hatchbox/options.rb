# frozen_string_literal: true

module Hatchbox
  class Options
    def initialize(flags:, values:)
      @flags = flags
      @values = values
      flags.each { |flag| define_reader(flag) }
    end

    def [](key)
      raise ArgumentError, "This command has no --#{key.to_s.tr("_", "-")} flag." unless flags.any? { |flag| flag.key == key }

      public_send(key)
    end

    def key?(key)
      values.key?(key)
    end

    def fetch(key, default: nil)
      return default unless respond_to?(key)

      public_send(key)
    end

    private

    attr_reader :flags, :values

    def define_reader(flag)
      define_singleton_method(flag.key) { values.fetch(flag.key) { flag.many? ? [] : nil } }
    end
  end
end
