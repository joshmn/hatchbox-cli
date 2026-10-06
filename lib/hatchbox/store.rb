# frozen_string_literal: true

module Hatchbox
  class Store
    PATH = File.join(Dir.home, ".hatchbox")

    attr_reader :path

    def initialize(path: PATH)
      @path = path
    end

    def exists?
      File.file?(path)
    end

    def data
      @data ||= load
    end

    def update
      fresh = load
      yield(fresh)
      write(fresh)
      @data = fresh
    end

    def display_path
      Hatchbox.tilde(path)
    end

    private

    def load
      return {} unless exists?

      text = File.read(path)
      return {} if text.strip.empty?

      JSON.parse(text)
    rescue JSON::ParserError => e
      raise Hatchbox::Error, "#{display_path} is not valid JSON: #{e.message}\nFix it, or delete it and run hatchbox login to start a fresh one."
    end

    def write(fresh)
      temporary = "#{path}.#{Process.pid}.tmp"
      File.open(temporary, File::WRONLY | File::CREAT | File::TRUNC, 0o600) { |handle| handle.write("#{JSON.pretty_generate(fresh)}\n") }
      File.rename(temporary, path)
    end
  end
end
