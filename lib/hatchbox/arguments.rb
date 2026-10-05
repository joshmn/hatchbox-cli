# frozen_string_literal: true

module Hatchbox
  class Arguments
    def initialize(specs:, values:)
      @specs = specs
      @values = values
      @bound = {}
      @extra = values.dup
      specs.each { |spec| bind(spec) }
    end

    def problem
      missing = specs.select { |spec| spec.required? && [nil, []].include?(bound[spec.name]) }
      return "Must specify #{missing.map { |spec| spec.label }.join(" and ")}." if missing.any?
      return nil if extra.empty?
      return "Unexpected argument: #{extra.join(" ")}" unless specs.length == 1

      "Only one #{specs.first.label} at a time, got #{values.join(" ")}. Quote it as one argument if it has spaces."
    end

    private

    attr_reader :specs, :values, :bound, :extra

    def bind(spec)
      bound[spec.name] = spec.many? ? extra.shift(extra.length) : extra.shift
      define_singleton_method(spec.name) { bound[spec.name] }
    end
  end
end
