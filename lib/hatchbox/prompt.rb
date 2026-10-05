# frozen_string_literal: true

module Hatchbox
  class Prompt
    def available?
      !tty.nil?
    end

    def ask(question:, io: $stderr)
      return nil unless available?

      io.print(question)
      io.flush
      answer = tty.gets
      answer.nil? ? nil : answer.strip
    end

    def secret(question:, io: $stderr)
      return nil unless available?

      io.print(question)
      io.flush
      answer = tty.noecho { |input| input.gets }
      io.puts
      answer.nil? ? nil : answer.strip
    end

    def yes?(question:, io: $stderr)
      ["y", "yes"].include?(ask(question: question, io: io).to_s.downcase)
    end

    private

    def tty
      return @tty if @opened

      @opened = true
      @tty = begin
        File.open("/dev/tty", "r")
      rescue SystemCallError
        nil
      end
    end
  end
end
