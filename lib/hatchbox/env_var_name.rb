# frozen_string_literal: true

module Hatchbox
  module EnvVarName
    USABLE = /\A[A-Z0-9_]+\z/.freeze

    class << self
      def clean(name)
        cleaned = name.strip.upcase
        raise Hatchbox::Error, "#{name} is not a name Hatchbox takes. Use letters, numbers and underscores." unless cleaned =~ USABLE

        cleaned
      end
    end
  end
end
