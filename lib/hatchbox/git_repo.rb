# frozen_string_literal: true

module Hatchbox
  module GitRepo
    class << self
      def remote_paths
        output, status = Open3.capture2("git", "config", "--get-regexp", "^remote\\..*\\.url$", err: File::NULL)
        return [] unless status.success?

        output.lines.map { |line| normalize(line.split(" ", 2).last) }.compact.uniq
      rescue Errno::ENOENT
        []
      end

      def normalize(url)
        text = url.to_s.strip.sub(/\.git\z/, "").sub(%r{/+\z}, "")
        text = text.sub(%r{\A[a-z][a-z0-9+.-]*://}i, "")
        text = text.sub(%r{\A[^@/]+@}, "")
        text = text.sub(%r{\A[^/:]*\.[^/:]*(:[0-9]+)?[:/]}, "")
        text = text.sub(%r{\A/}, "")
        text.empty? ? nil : text.downcase
      end
    end
  end
end
