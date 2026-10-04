# frozen_string_literal: true

require "json"
require "net/http"
require "uri"
require "optparse"
require "pathname"
require "socket"
require "shellwords"
require "tmpdir"
require "fileutils"
require "time"
require "io/console"
require "open3"
require "rbconfig"

require "hatchbox/version"

module Hatchbox
  class Error < StandardError; end

  API_BASE = ENV["HATCHBOX_API_BASE"] || "https://hatchbox.io/api/v1"
  GLOBAL_CONFIG = File.join(Dir.home, ".hatchbox")
  POLL_SECONDS = 3
  MAX_WAIT_SECONDS = 3600
  DEFAULT_SSH_USER = "deploy"
  DEFAULT_SSH_PORT = "22"
  FINISHED = ["completed", "failed", "aborted"].freeze
  APP_ROLES = ["web", "worker", "cron", "app"].freeze
  ROLES = ["app", "web", "worker", "cron", "load_balancer", "postgresql", "mysql", "redis", "memcached", "elasticsearch"].freeze
  NAME = /\A[A-Za-z0-9_-]+\z/.freeze

  class << self
    def blank?(value)
      value.nil? || value.to_s.strip.empty?
    end

    def color?(io = $stdout)
      return false if ENV["NO_COLOR"]

      io.tty?
    end

    def run(argv, env: {})
      started = system(env, *argv)
      raise Error, "#{argv.first} is required and is not installed." if started.nil?

      exit_code($?)
    end

    def exit_code(status)
      return status.exitstatus if status.exitstatus

      128 + status.termsig.to_i
    end

    def parallel(jobs)
      threads = jobs.map do |key, job|
        thread = Thread.new do
          Thread.current.report_on_exception = false
          job.call
        end
        [key, thread]
      end
      threads.to_h { |key, thread| [key, thread.value] }
    end

    def ssh_options
      Shellwords.split(ENV["HATCHBOX_SSH_OPTIONS"].to_s)
    end

    def platform
      "hatchbox/#{VERSION} #{RbConfig::CONFIG["host_os"]}-#{RbConfig::CONFIG["host_cpu"]} ruby-#{RUBY_VERSION}"
    end

    def slug_id(slug)
      slug.to_s[/\A[0-9]+/]
    end

    def slug_name(slug)
      slug.to_s.sub(/\A[0-9]+-?/, "")
    end

    def check_name!(name)
      return if name =~ NAME

      raise Error, "#{name} is not a name Hatchbox takes. Use letters, numbers, hyphens and underscores."
    end
  end
end

require "hatchbox/color"
require "hatchbox/ui"
require "hatchbox/ui/step"
require "hatchbox/printer"
require "hatchbox/formatter"
require "hatchbox/http"
require "hatchbox/http/response"
require "hatchbox/client"
require "hatchbox/config_line"
require "hatchbox/config_file"
require "hatchbox/config_locator"
require "hatchbox/config"
require "hatchbox/prompt"
require "hatchbox/token_store"
require "hatchbox/account_picker"
require "hatchbox/app_catalog"
require "hatchbox/target_messages"
require "hatchbox/target"
require "hatchbox/session"
require "hatchbox/app"
require "hatchbox/dyno"
require "hatchbox/fleet"
require "hatchbox/formation"
require "hatchbox/ssh_target"
require "hatchbox/database_picker"
require "hatchbox/database"
require "hatchbox/tunnel"
require "hatchbox/operation_result"
require "hatchbox/operation_output"
require "hatchbox/operation"
require "hatchbox/progress"
require "hatchbox/logs/journal"
require "hatchbox/logs/plan"
require "hatchbox/logs/entry"
require "hatchbox/logs/report"
require "hatchbox/logs/parser"
require "hatchbox/logs/connections"
require "hatchbox/logs/reader"
require "hatchbox/logs/planner"
require "hatchbox/activity"
require "hatchbox/log_resolver"
require "hatchbox/release_summary"
require "hatchbox/backup_schedule"
require "hatchbox/env_var_name"
require "hatchbox/remote_command"
require "hatchbox/git_repo"
require "hatchbox/remote_name"
require "hatchbox/app_chooser"
require "hatchbox/app_details"
require "hatchbox/registry"
require "hatchbox/argument_parser"
require "hatchbox/commands/context"
require "hatchbox/commands/output"
require "hatchbox/commands/tracking"
require "hatchbox/command"
require "hatchbox/commands/database_lookup"
require "hatchbox/commands/database_connection"
require "hatchbox/commands/ps/toggle"
require "hatchbox/commands/ps/fields"
require "hatchbox/commands/domains/paths"
require "hatchbox/commands/pg/tools"
require "hatchbox/commands/pg/query"
require "hatchbox/commands/pg/backups/tools"
require "hatchbox/commands/cron/fields"
require "hatchbox/commands/servers/lookup"
require "hatchbox/commands/servers/roles/change"
require "hatchbox/commands/auth/login"
require "hatchbox/commands/auth/logout"
require "hatchbox/commands/auth/token"
require "hatchbox/commands/auth/whoami"
require "hatchbox/commands/apps/list"
require "hatchbox/commands/apps/info"
require "hatchbox/commands/apps/create"
require "hatchbox/commands/apps/destroy"
require "hatchbox/commands/apps/rename"
require "hatchbox/commands/apps/open"
require "hatchbox/commands/apps/update"
require "hatchbox/commands/remotes"
require "hatchbox/commands/git/remote"
require "hatchbox/commands/config/list"
require "hatchbox/commands/config/get"
require "hatchbox/commands/config/set"
require "hatchbox/commands/config/unset"
require "hatchbox/commands/maintenance/status"
require "hatchbox/commands/maintenance/on"
require "hatchbox/commands/maintenance/off"
require "hatchbox/commands/git/providers"
require "hatchbox/commands/ps/list"
require "hatchbox/commands/ps/info"
require "hatchbox/commands/ps/restart"
require "hatchbox/commands/ps/stop"
require "hatchbox/commands/ps/start"
require "hatchbox/commands/ps/create"
require "hatchbox/commands/ps/update"
require "hatchbox/commands/ps/destroy"
require "hatchbox/commands/logs"
require "hatchbox/commands/run/attached"
require "hatchbox/commands/run/detached"
require "hatchbox/commands/ps/exec"
require "hatchbox/commands/ps/forward"
require "hatchbox/commands/ps/socks"
require "hatchbox/commands/ps/copy"
require "hatchbox/commands/deploy"
require "hatchbox/commands/status"
require "hatchbox/commands/releases/list"
require "hatchbox/commands/releases/info"
require "hatchbox/commands/releases/output"
require "hatchbox/commands/releases/rollback"
require "hatchbox/commands/builds/list"
require "hatchbox/commands/builds/info"
require "hatchbox/commands/domains/list"
require "hatchbox/commands/domains/add"
require "hatchbox/commands/domains/remove"
require "hatchbox/commands/domains/info"
require "hatchbox/commands/domains/update"
require "hatchbox/commands/domains/clear"
require "hatchbox/commands/pg/psql"
require "hatchbox/commands/pg/info"
require "hatchbox/commands/pg/credentials_url"
require "hatchbox/commands/pg/pull"
require "hatchbox/commands/pg/ps"
require "hatchbox/commands/pg/locks"
require "hatchbox/commands/pg/blocking"
require "hatchbox/commands/pg/outliers"
require "hatchbox/commands/pg/bloat"
require "hatchbox/commands/pg/vacuum_stats"
require "hatchbox/commands/pg/kill"
require "hatchbox/commands/pg/killall"
require "hatchbox/commands/pg/backups/list"
require "hatchbox/commands/pg/backups/capture"
require "hatchbox/commands/pg/backups/info"
require "hatchbox/commands/pg/backups/url"
require "hatchbox/commands/pg/backups/download"
require "hatchbox/commands/pg/backups/schedules"
require "hatchbox/commands/pg/backups/schedule"
require "hatchbox/commands/pg/backups/unschedule"
require "hatchbox/commands/pg/backups/test"
require "hatchbox/commands/redis/cli"
require "hatchbox/commands/mysql/cli"
require "hatchbox/commands/cron/list"
require "hatchbox/commands/cron/add"
require "hatchbox/commands/cron/info"
require "hatchbox/commands/cron/update"
require "hatchbox/commands/cron/remove"
require "hatchbox/commands/servers/list"
require "hatchbox/commands/servers/info"
require "hatchbox/commands/servers/reboot"
require "hatchbox/commands/servers/provision"
require "hatchbox/commands/servers/activity"
require "hatchbox/commands/servers/roles/list"
require "hatchbox/commands/servers/roles/set"
require "hatchbox/commands/servers/roles/add"
require "hatchbox/commands/servers/roles/remove"
require "hatchbox/commands/firewall/list"
require "hatchbox/commands/firewall/info"
require "hatchbox/commands/firewall/add"
require "hatchbox/commands/firewall/remove"
require "hatchbox/commands/scripts/activity"
require "hatchbox/help"
require "hatchbox/help_page"
require "hatchbox/global_flags"
require "hatchbox/cli"
