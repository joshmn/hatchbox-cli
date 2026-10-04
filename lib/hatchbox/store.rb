# frozen_string_literal: true

module Hatchbox
  class Store
    attr_reader :path

    def initialize(path: Hatchbox::GLOBAL_CONFIG)
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
      path.sub(/\A#{Regexp.escape(Dir.home)}/, "~")
    end

    private

    def load
      return {} unless exists?

      text = File.read(path)
      return {} if text.strip.empty?
      return Hatchbox::LegacyConfig.new(text).to_h unless text.lstrip.start_with?("{")

      JSON.parse(text)
    rescue JSON::ParserError => e
      raise Hatchbox::Error, "#{display_path} is not valid JSON: #{e.message}"
    end

    def write(fresh)
      temporary = "#{path}.#{Process.pid}.tmp"
      File.open(temporary, File::WRONLY | File::CREAT | File::TRUNC, 0o600) { |handle| handle.write("#{JSON.pretty_generate(fresh)}\n") }
      File.chmod(0o600, temporary)
      File.rename(temporary, path)
    end
  end
end
