# frozen_string_literal: true

module Hatchbox
  module ConfigLocator
    class << self
      def find
        Pathname.new(Dir.pwd).ascend do |dir|
          candidate = dir.join(".hatchbox")
          return candidate.to_s if candidate.file? && candidate.to_s != Hatchbox::GLOBAL_CONFIG
        end
        nil
      end

      def target
        found = find
        return found if found

        File.join((repo_root || Dir.pwd).to_s, ".hatchbox")
      end

      def repo_root
        Pathname.new(Dir.pwd).ascend { |dir| break dir.to_s if dir.join(".git").exist? }
      end
    end
  end
end
