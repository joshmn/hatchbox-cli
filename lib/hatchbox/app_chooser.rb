# frozen_string_literal: true

module Hatchbox
  class AppChooser
    def initialize(catalog:, prompt:)
      @catalog = catalog
      @prompt = prompt
    end

    def choose(filter)
      rows = catalog.entries(filter: filter)
      raise Hatchbox::Error, Hatchbox.blank?(filter) ? "The token can see no apps at all." : "No app matches #{filter}." if rows.empty?

      matched = rows.select { |row| repos.include?(Hatchbox::GitRepo.normalize(row[:record]["repo_path"])) }
      return announce(matched.first) if matched.length == 1

      stuck(matched) unless prompt.available?
      pick(matched.any? ? matched : rows, matched: matched)
    end

    private

    attr_reader :catalog, :prompt

    def repos
      @repos ||= Hatchbox::GitRepo.remote_paths
    end

    def announce(row)
      $stderr.puts("Found #{row[:slug]}, which deploys #{row[:record]["repo_path"]}")
      row[:slug]
    end

    def stuck(matched)
      raise Hatchbox::Error, (["More than one app deploys this repo. Pick one with -a:"] + matched.map { |row| row[:slug] }).join("\n") if matched.any?

      raise Hatchbox::Error, "git:remote needs a terminal to pick from, or pass -a APP and -r REMOTE."
    end

    def pick(pool, matched:)
      $stderr.puts
      $stderr.puts("Apps that deploy #{Hatchbox::Formatter.list(matched.map { |row| row[:record]["repo_path"] }.uniq)}:") if matched.any?
      pool.each_with_index { |row, index| $stderr.puts(format("%3d  %-34s %s", index + 1, row[:slug], row[:account])) }
      $stderr.puts
      pool[prompt.ask_number(question: "Which app? ", count: pool.length) - 1][:slug]
    end
  end
end
