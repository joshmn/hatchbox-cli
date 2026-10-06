# frozen_string_literal: true

module Hatchbox
  module Ui
    PREFIX = " !    "

    Step = Struct.new(:status)

    class << self
      def header(text)
        puts(Hatchbox::Color.bold("=== #{text}"))
      end

      def action(message)
        $stderr.print("#{message}... ")
        $stderr.flush
        step = Step.new
        result = yield(step)
        $stderr.puts(step.status || "done")
        result
      rescue Interrupt, StandardError
        $stderr.puts("!")
        raise
      end

      def error(message)
        emit(message, color: :red)
      end

      def warning(message)
        emit(message, color: :yellow)
      end

      def note(message)
        $stderr.puts(Hatchbox::Color.dim(message, io: $stderr))
      end

      def confirm(expected:, supplied:, lines:, prompt:)
        return if supplied == expected
        raise Hatchbox::Error, "Confirmation #{supplied} did not match #{expected}. Aborted." unless Hatchbox.blank?(supplied)
        raise Hatchbox::Error, (lines + ["To proceed, re-run this command with --confirm #{expected}"]).join("\n") unless prompt.available?

        warning((["Warning: potentially destructive action"] + lines + ["To proceed, type \"#{expected}\" or re-run this command with --confirm #{expected}"]).join("\n"))
        $stderr.puts
        answer = prompt.ask(question: "> ", io: $stderr)
        raise Hatchbox::Error, "Confirmation did not match #{expected}. Aborted." unless answer == expected
      end

      private

      def emit(message, color:)
        rows = message.to_s.split("\n")
        rows = [""] if rows.empty?
        rows.each { |row| $stderr.puts(Hatchbox::Color.public_send(color, "#{PREFIX}#{row}".rstrip, io: $stderr)) }
      end
    end
  end
end
