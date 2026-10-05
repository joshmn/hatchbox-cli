# frozen_string_literal: true

module Hatchbox
  module Ui
    PREFIX = " !    "

    class << self
      def header(text)
        puts(Hatchbox::Color.bold("=== #{text}"))
      end

      def action(message)
        $stderr.print("#{message}... ")
        $stderr.flush
        step = Hatchbox::Ui::Step.new
        result = yield(step)
        $stderr.puts(step.status || "done")
        result
      rescue Interrupt, StandardError
        $stderr.puts("!")
        raise
      end

      def error(message)
        emit(message, code: 31)
      end

      def warning(message)
        emit(message, code: 33)
      end

      def note(message)
        $stderr.puts(paint(message, code: 90))
      end

      def confirm(expected:, supplied:, lines:, prompt:)
        return if supplied == expected
        raise Hatchbox::Error, "Confirmation #{supplied} did not match #{expected}. Aborted." unless Hatchbox.blank?(supplied)
        raise Hatchbox::Error, (lines + ["To proceed, re-run this command with --confirm #{expected}"]).join("\n") unless prompt.available?

        warning((["WARNING: Potentially Destructive Action"] + lines + ["To proceed, type \"#{expected}\" or re-run this command with --confirm #{expected}"]).join("\n"))
        $stderr.puts
        answer = prompt.ask(question: "> ", io: $stderr)
        raise Hatchbox::Error, "Confirmation did not match #{expected}. Aborted." unless answer == expected
      end

      def paint(text, code:, io: $stderr)
        Hatchbox::Color.paint(text, code: code, io: io)
      end

      private

      def emit(message, code:)
        rows = message.to_s.split("\n")
        rows = [""] if rows.empty?
        rows.each { |row| $stderr.puts(paint("#{PREFIX}#{row}".rstrip, code: code)) }
      end
    end
  end
end
