# frozen_string_literal: true

module Hatchbox
  module Logs
    class Journal
      FIELDS = "MESSAGE,_SYSTEMD_UNIT,_SYSTEMD_USER_UNIT,UNIT,USER_UNIT,SYSLOG_IDENTIFIER"
      LIVE = "{\"__hbx\":\"live\"}"

      def initialize(units: [], identifiers: [], lines: 100, follow: false, since: nil, units_only: false)
        @units = units
        @identifiers = identifiers
        @lines = lines
        @follow = follow
        @since = since
        @units_only = units_only
      end

      def script
        [
          "set -u",
          "[ -n \"${XDG_RUNTIME_DIR:-}\" ] || export XDG_RUNTIME_DIR=/run/user/$(id -u)",
          "args=''",
          "found=0",
          "system=0",
          *units.map { |unit| check(unit) },
          *identifiers.map { |name| "args=\"$args -t #{quote(name)}\"; found=1" },
          "if [ \"$found\" = 0 ]; then exit 3; fi",
          "if [ \"$system\" = 1 ] && [ \"$(id -u)\" != 0 ] && ! id -nG | tr ' ' '\\n' | grep -qxE 'adm|systemd-journal'; then echo #{quote(JSON.dump("__hbx" => "blind"))}; fi",
          *reading
        ].join("\n")
      end

      private

      attr_reader :units, :identifiers, :lines, :follow, :since, :units_only

      def check(unit)
        name = quote(unit)
        [
          "if systemctl --user cat #{name} >/dev/null 2>&1; then args=\"$args --user-unit=#{unit}\"; found=1; echo #{marker(kind: "unit", unit: unit, scope: "user")}",
          "elif systemctl cat #{name} >/dev/null 2>&1; then args=\"$args -u #{unit}\"; found=1; system=1; echo #{marker(kind: "unit", unit: unit, scope: "system")}",
          "else echo #{marker(kind: "missing", unit: unit, scope: nil)}; fi"
        ].join("\n")
      end

      def marker(kind:, unit:, scope:)
        data = { "__hbx" => kind, "unit" => unit }
        data["scope"] = scope if scope
        quote(JSON.dump(data))
      end

      def reading
        return ["exit 0"] if units_only

        common = "journalctl -q --all -o json --output-fields=#{FIELDS} $args"
        window = "-n #{lines.to_i}#{Hatchbox.blank?(since) ? "" : " --since #{quote(since)}"}"
        return ["exec #{common} #{window} --no-pager"] unless follow

        [
          "out=$(#{common} #{window} --no-pager)",
          "[ -n \"$out\" ] && printf '%s\\n' \"$out\"",
          "echo #{quote(LIVE)}",
          "cursor=$(printf '%s\\n' \"$out\" | tail -n 1 | sed -n 's/^{ *\"__CURSOR\" *: *\"\\([^\"]*\\)\".*/\\1/p')",
          "if [ -n \"$cursor\" ]; then exec #{common} -f --after-cursor=\"$cursor\"; fi",
          "exec #{common} -f -n 0"
        ]
      end

      def quote(text)
        Shellwords.escape(text)
      end
    end
  end
end
