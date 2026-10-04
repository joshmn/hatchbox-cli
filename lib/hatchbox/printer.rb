# frozen_string_literal: true

module Hatchbox
  module Printer
    ANSI = /\e\[[0-9;]*m/.freeze

    class << self
      def styled_hash(pairs)
        rows = pairs.reject { |_key, value| empty?(value) }
        return if rows.empty?

        width = rows.map { |key, _value| key.length }.max + 2
        rows.each do |key, value|
          lines = Array(value).map { |line| line.to_s }
          puts("#{"#{key}:".ljust(width)}#{lines.first}".rstrip)
          lines.drop(1).each { |line| puts("#{" " * width}#{line}".rstrip) }
        end
      end

      def table(rows:, columns:)
        titles = columns.map { |title, _getter| title }
        cells = rows.map { |row| columns.map { |_title, getter| getter.call(row).to_s } }
        widths = titles.each_with_index.map do |title, index|
          ([title] + cells.map { |cell| cell[index] }).map { |text| visible(text) }.max
        end
        puts(line(texts: titles, widths: widths))
        puts(widths.map { |width| "-" * width }.join("  "))
        cells.each { |cell| puts(line(texts: cell, widths: widths)) }
      end

      def columns(rows)
        return if rows.empty?

        count = rows.map { |row| row.length }.max
        widths = (0...count).map { |index| rows.map { |row| visible(row[index].to_s) }.max }
        rows.each { |row| puts(line(texts: row.map { |cell| cell.to_s }, widths: widths)) }
      end

      def visible(text)
        text.to_s.gsub(ANSI, "").length
      end

      private

      def empty?(value)
        return true if value.nil?
        return value.strip.empty? if value.is_a?(String)
        return value.empty? if value.is_a?(Array)

        false
      end

      def line(texts:, widths:)
        texts.each_with_index.map { |text, index| pad(text: text, width: widths[index]) }.join("  ").rstrip
      end

      def pad(text:, width:)
        "#{text}#{" " * [width - visible(text), 0].max}"
      end
    end
  end
end
