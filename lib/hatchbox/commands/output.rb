# frozen_string_literal: true

module Hatchbox
  module Commands
    module Output
      private

      def ui
        Hatchbox::Ui
      end

      def printer
        Hatchbox::Printer
      end

      def formatter
        Hatchbox::Formatter
      end

      def color
        Hatchbox::Color
      end

      def json?
        options.key?(:json)
      end

      def print_json(data)
        puts(JSON.pretty_generate(data))
        0
      end
    end
  end
end
