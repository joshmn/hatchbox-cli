# frozen_string_literal: true

module Hatchbox
  module Logs
    class Plan
      attr_reader :target, :units, :identifiers

      def initialize(target:, units:, identifiers:)
        @target = target
        @units = units
        @identifiers = identifiers
      end

      def journal(lines:, follow:, since:, units_only:)
        Hatchbox::Logs::Journal.new(
          units: units.keys,
          identifiers: identifiers.keys,
          lines: lines,
          follow: follow,
          since: since,
          units_only: units_only
        )
      end
    end
  end
end
