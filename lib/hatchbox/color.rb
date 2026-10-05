# frozen_string_literal: true

module Hatchbox
  module Color
    CODES = { red: 31, green: 32, yellow: 33, cyan: 36, dim: 90, bold: 1 }.freeze

    class << self
      CODES.each { |name, code| define_method(name) { |text| paint(text, code: code) } }

      def paint(text, code:, io: $stdout)
        Hatchbox.color?(io) ? "\e[#{code}m#{text}\e[0m" : text
      end
    end
  end
end
