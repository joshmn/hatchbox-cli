# frozen_string_literal: true

module Hatchbox
  module Logs
    Plan = Struct.new(:target, :units, :identifiers, keyword_init: true) do
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
