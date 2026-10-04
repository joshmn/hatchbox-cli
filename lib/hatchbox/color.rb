# frozen_string_literal: true

module Hatchbox
  module Color
    class << self
      def red(text)
        paint(text, code: 31)
      end

      def green(text)
        paint(text, code: 32)
      end

      def yellow(text)
        paint(text, code: 33)
      end

      def cyan(text)
        paint(text, code: 36)
      end

      def dim(text)
        paint(text, code: 90)
      end

      def bold(text)
        paint(text, code: 1)
      end

      private

      def paint(text, code:)
        return text unless Hatchbox.color?

        "\e[#{code}m#{text}\e[0m"
      end
    end
  end
end
