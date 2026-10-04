# frozen_string_literal: true

module Hatchbox
  module Logs
    class Connections
      def initialize
        @queue = Queue.new
        @children = []
      end

      def open(target:, script:, index:)
        stdin, stdout, stderr, waiter = Open3.popen3(*target.ssh(command: "bash -c #{Shellwords.escape(script)}"))
        stdin.close
        children << waiter
        Thread.new { pump(stream: stdout, index: index) }
        Thread.new { stderr.each_line { |line| queue << [:err, index, line] } }
        Thread.new { queue << [:exit, index, Hatchbox.exit_code(waiter.value)] }
      rescue Errno::ENOENT
        raise Hatchbox::Error, "ssh is required and is not installed."
      end

      def pop
        queue.pop
      end

      def close
        children.each do |waiter|
          next unless waiter.alive?

          Process.kill("TERM", waiter.pid)
        rescue SystemCallError
          nil
        end
      end

      private

      attr_reader :queue, :children

      def pump(stream:, index:)
        stream.each_line { |line| queue << [:line, index, line] }
        queue << [:eof, index, nil]
      end
    end
  end
end
