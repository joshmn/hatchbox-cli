# frozen_string_literal: true

module Hatchbox
  class Arguments
    class Spec
      attr_reader :name, :label

      def initialize(name:, text:)
        @name = name
        @optional = text.start_with?("[") && text.end_with?("]")
        inner = @optional ? text[1..-2] : text
        @many = inner.end_with?("...")
        @label = inner.delete_suffix("...")
      end

      def optional?
        @optional
      end

      def required?
        !optional?
      end

      def many?
        @many
      end
    end
  end
end
