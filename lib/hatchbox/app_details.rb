# frozen_string_literal: true

module Hatchbox
  class AppDetails
    EXTENDED = [
      ["Pre Build Script", "pre_build_script"],
      ["Build Script", "build_script"],
      ["Post Build Script", "post_build_script"],
      ["Post Deploy Script", "post_deploy_script"],
      ["Failed Deploy Script", "failed_deploy_script"],
      ["Caddyfile", "caddyfile"],
      ["DNS Provider", "dns_provider"],
      ["DNS API User", "dns_api_user"]
    ].freeze

    def initialize(data:, formation:)
      @data = data
      @formation = formation
    end

    def pairs(extended:)
      cluster = data["cluster"] || {}
      rows = [
        ["Databases", data["databases"].map { |record| database_line(record) }],
        ["Auto Deploy", Hatchbox::Formatter.yes_no(data["auto_deploy"])],
        ["Branch", data["branch"]],
        ["Cluster", "#{cluster["name"]} (#{[cluster["provider"], cluster["region"]].compact.join(" ")})"],
        ["Domains", data["domains"]],
        ["Git Provider", data["git_provider"]],
        ["Health Check", data["health_check_uri"]],
        ["Id", data["id"].to_s],
        ["Last Deploy", last_deploy],
        ["Maintenance", Hatchbox::Formatter.yes_no(data["maintenance"])],
        ["Processes", data["processes"].map { |row| process_line(row) }],
        ["Repo", data["repo_path"]],
        ["Servers", data["servers"].map { |server| "#{server["name"]} (#{Array(server["roles"]).join(", ")})" }],
        ["Team", data["team"]],
        ["Web URL", data["web_url"]]
      ]
      rows.concat(EXTENDED.map { |title, key| [title, data[key].to_s.split("\n")] }) if extended
      rows.sort_by { |key, _value| key }
    end

    def shell_pairs
      {
        "databases" => data["databases"].map { |record| record["name"] }.join(","),
        "auto_deploy" => data["auto_deploy"],
        "branch" => data["branch"],
        "cluster" => (data["cluster"] || {})["name"],
        "domains" => data["domains"].join(","),
        "git_provider" => data["git_provider"],
        "health_check_uri" => data["health_check_uri"],
        "id" => data["id"],
        "last_deploy_at" => data["last_deploy_at"],
        "last_deploy_sha" => data["last_deploy_sha"],
        "maintenance" => data["maintenance"],
        "name" => data["name"],
        "processes" => data["processes"].map { |row| row["name"] }.join(","),
        "repo_path" => data["repo_path"],
        "servers" => data["servers"].map { |server| server["name"] }.join(","),
        "team" => data["team"],
        "web_url" => data["web_url"]
      }
    end

    private

    attr_reader :data, :formation

    def database_line(record)
      attached = record["as"].empty? ? "" : " as #{record["as"].join(", ")}"
      "#{record["name"]} (#{record["engine"]})#{attached}"
    end

    def process_line(row)
      "#{row["name"]} (#{formation.where(row)})#{row["active"] ? "" : ", disabled"}"
    end

    def last_deploy
      sha = data["last_deploy_sha"].to_s
      return nil if sha.empty?

      [sha[0, 7], Hatchbox::Formatter.date(data["last_deploy_at"])].compact.join(" ")
    end
  end
end
