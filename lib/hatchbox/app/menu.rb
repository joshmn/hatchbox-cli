# frozen_string_literal: true

module Hatchbox
  class App
    class Menu
      def initialize(rows:, guess:)
        @rows = rows
        @guess = guess
      end

      def show(io: $stderr)
        io.puts(Hatchbox::Color.dim(line(number: "#", id: "ID", name: "Name", team: "Team")))
        rows.each_with_index do |row, index|
          text = line(number: (index + 1).to_s, id: row[:id], name: row[:name], team: row[:account])
          io.puts(row == guess ? Hatchbox::Color.bold(Hatchbox::Color.green(text)) : text)
        end
        io.puts
      end

      def ask(prompt)
        loop do
          answer = prompt.ask(question: question)
          raise Hatchbox::Error, "Nothing picked." if answer.nil?

          found = resolve(answer)
          return found[:slug] if found

          $stderr.puts(complaint(answer))
        end
      end

      private

      attr_reader :rows, :guess

      def question
        return "Which app? Enter for #{guess[:name]}, or a number or name: " if guess

        "Which app? A number or name: "
      end

      def resolve(answer)
        return guess if answer.empty?
        return rows[answer.to_i - 1] if answer.match?(/\A[0-9]+\z/) && answer.to_i.between?(1, rows.length)

        found = matches(answer)
        found.length == 1 ? found.first : nil
      end

      def matches(answer)
        wanted = answer.downcase
        rows.select { |row| [row[:id].to_s, row[:slug].downcase, row[:name].downcase].include?(wanted) }
      end

      def complaint(answer)
        return "Pick a number or name from the list." if answer.empty?
        return "More than one app is called #{answer}, so use a number." if matches(answer).length > 1

        "#{answer} isn't on the list."
      end

      def line(number:, id:, name:, team:)
        "  #{number.rjust(widths[:number])}  #{id.to_s.ljust(widths[:id])}  #{name.to_s.ljust(widths[:name])}  #{team}".rstrip
      end

      def widths
        @widths ||= {
          number: rows.length.to_s.length,
          id: [rows.map { |row| row[:id].to_s.length }.max, 2].max,
          name: [rows.map { |row| row[:name].to_s.length }.max, 4].max
        }
      end
    end
  end
end
