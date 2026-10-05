# frozen_string_literal: true

module Hatchbox
  module RemoteName
    SUFFIX = /[-_](production|prod|staging|stage|qa|dev|development|test|demo|preview)\z/i.freeze
    EXPANDED = { "" => "production", "prod" => "production", "stage" => "staging", "dev" => "development" }.freeze

    class << self
      def guess(slug)
        found = Hatchbox.slug_name(slug)[SUFFIX, 1].to_s.downcase
        EXPANDED.fetch(found, found)
      end

      def validate(remote)
        return unless remote =~ /[:=\s]/

        raise Hatchbox::Error, "A remote name cannot contain a colon, an equals sign or a space."
      end
    end
  end
end
