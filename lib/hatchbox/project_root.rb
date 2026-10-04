# frozen_string_literal: true

module Hatchbox
  module ProjectRoot
    class << self
      def find
        repo || Dir.pwd
      end

      def repo
        Pathname.new(Dir.pwd).ascend { |dir| break dir.to_s if dir.join(".git").exist? }
      end
    end
  end
end
