# frozen_string_literal: true

module Hatchbox
  module Activity
    NAMESPACES = ["Apps", "Servers", "Clusters", "DatabaseClusters", "Databases", "Scripts"].freeze
    DEPLOY = "Apps::Deploy"

    class << self
      def change(row)
        name = row["name"].to_s
        return deploy(row) if name == DEPLOY

        text = humanize(name)
        description = row["description"].to_s.strip
        return text if description.empty?

        "#{text}: #{description}"
      end

      def state(row, completed: "")
        raw = row["state"].to_s
        return completed if raw == "completed"
        return Hatchbox::Color.red(raw) if ["failed", "aborted"].include?(raw)

        Hatchbox::Color.yellow(raw)
      end

      def deploy?(row)
        row["name"].to_s == DEPLOY
      end

      def humanize(name)
        parts = name.split("::")
        parts.shift if parts.length > 1 && NAMESPACES.include?(parts.first)
        words = parts.map { |part| part.gsub(/([a-z0-9])([A-Z])/, "\\1 \\2").tr("_", " ").downcase }
        return capitalize(words.first.to_s) if words.length < 2

        "#{capitalize(words.last)} #{words[-2]}"
      end

      def rows(list)
        list.map do |row|
          change = change(row)
          change = "#{change[0, 47]}..." if change.length > 50
          [row["id"].to_s, change, row["username"].to_s, Hatchbox::Formatter.date(row["created_at"]).to_s, state(row)]
        end
      end

      private

      def deploy(row)
        sha = row["commit_sha"].to_s
        subject = row["description"].to_s.strip.split("\n").first.to_s
        ["Deploy", sha[0, 7], subject].reject { |part| part.empty? }.join(" ")
      end

      def capitalize(word)
        "#{word[0].to_s.upcase}#{word[1..-1]}"
      end
    end
  end
end
