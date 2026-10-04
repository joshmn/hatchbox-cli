# frozen_string_literal: true

module Hatchbox
  class App
    class Chooser
      def initialize(catalog:, prompt:)
        @catalog = catalog
        @prompt = prompt
      end

      def choose(filter)
        rows = catalog.entries(filter: filter)
        raise Hatchbox::Error, Hatchbox.blank?(filter) ? "The token can see no apps at all." : "No app matches #{filter}." if rows.empty?

        matched = rows.select { |row| deploys_here?(row) }
        return announce(matched.first) if matched.length == 1 && !prompt.available?

        stuck(matched) unless prompt.available?
        guess = guess_from(matched)
        $stderr.puts
        intro(guess: guess, matched: matched)
        menu = Hatchbox::App::Menu.new(rows: ([guess] + matched + rows).compact.uniq, guess: guess)
        menu.show
        menu.ask(prompt)
      end

      private

      attr_reader :catalog, :prompt

      def repos
        @repos ||= Hatchbox::GitRepo.remote_paths
      end

      def deploys_here?(row)
        repos.include?(Hatchbox::GitRepo.normalize(row[:record]["repo_path"]))
      end

      def guess_from(matched)
        return matched.first if matched.length == 1

        named = matched.select { |row| repos.any? { |repo| repo.split("/").last == row[:name].downcase } }
        named.length == 1 ? named.first : nil
      end

      def intro(guess:, matched:)
        if guess
          $stderr.puts(Hatchbox::Color.bold(Hatchbox::Color.green("This looks like #{guess[:name]} (#{guess[:id]}), which deploys #{guess[:record]["repo_path"]}.")))
          $stderr.puts
        elsif matched.any?
          $stderr.puts("#{matched.length} apps deploy this repo, they're at the top.")
          $stderr.puts
        end
      end

      def announce(row)
        $stderr.puts("Found #{row[:slug]}, which deploys #{row[:record]["repo_path"]}")
        row[:slug]
      end

      def stuck(matched)
        raise Hatchbox::Error, (["More than one app deploys this repo. Pick one with -a:"] + matched.map { |row| row[:slug] }).join("\n") if matched.any?

        raise Hatchbox::Error, "git:remote needs a terminal to pick from, or pass -a APP and -r REMOTE."
      end
    end
  end
end
