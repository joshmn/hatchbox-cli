# frozen_string_literal: true

module Hatchbox
  module BackupSchedule
    class << self
      def show(config)
        return Hatchbox::Ui.error(config["error"]) if config.key?("error")
        return puts("Backups are not scheduled.") unless config["backup_enabled"]

        Hatchbox::Printer.styled_hash([
          ["Frequency", config["backup_frequency"]],
          ["Provider", config["backup_provider"]],
          ["Bucket", config["backup_bucket"]],
          ["Region", config["backup_region"]],
          ["Endpoint", config["backup_endpoint"]],
          ["Retention", Hatchbox.blank?(config["backup_retention_period"]) ? "forever" : config["backup_retention_period"]],
          ["Credentials", config["backup_credentials_set"] ? "set" : "missing"],
          ["AppSignal", config["appsignal"] ? "on" : nil],
          ["Honeybadger", config["honeybadger_checkin_id"]],
          ["Last Backup", Hatchbox::Formatter.date(config["last_backup_at"])]
        ])
      end

      def line(config)
        return config["error"] if config.key?("error")
        return "off" unless config["backup_enabled"]

        place = [config["backup_provider"], config["backup_bucket"]].compact.join(" ")
        kept = Hatchbox.blank?(config["backup_retention_period"]) ? "" : ", kept #{config["backup_retention_period"]}"
        "on, #{config["backup_frequency"]} to #{place}#{kept}"
      end
    end
  end
end
