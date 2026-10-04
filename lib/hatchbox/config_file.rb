# frozen_string_literal: true

module Hatchbox
  class ConfigFile
    attr_reader :path

    def initialize(path)
      @path = path.to_s
    end

    def exists?
      File.file?(path)
    end

    def lines
      return [] unless exists?

      File.readlines(path).map { |line| line.chomp }
    end

    def settings
      found = {}
      lines.each do |line|
        key = Hatchbox::ConfigLine.key(line)
        found[key] = line.split("=", 2).last.strip if key
      end
      found
    end

    def write(rows)
      File.write(path, rows.map { |row| "#{row}\n" }.join)
    end

    def writable?
      return File.writable?(path) if exists?

      File.writable?(File.dirname(path))
    end

    def rewrite(replacement)
      written = false
      kept = lines.map do |line|
        next line unless yield(line)
        next nil if written || replacement.nil?

        written = true
        replacement
      end
      kept = kept.compact
      kept << replacement unless written || replacement.nil?
      write(kept)
    end
  end
end
