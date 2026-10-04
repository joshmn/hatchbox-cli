# frozen_string_literal: true

module Hatchbox
  module Logs
    class Parser
      def initialize(plans:, report:)
        @plans = plans
        @report = report
        @seen = Hash.new { |hash, key| hash[key] = {} }
        @order = 0
      end

      def parse(index:, text:)
        return nil if text.strip.empty?

        data = JSON.parse(text)
        return marker(index: index, data: data) if data.key?("__hbx")

        cursor = data["__CURSOR"].to_s
        return nil if !cursor.empty? && seen[index].key?(cursor)

        seen[index][cursor] = true unless cursor.empty?
        build(plan: plans[index], data: data)
      rescue JSON::ParserError
        $stderr.print(text)
        nil
      end

      private

      attr_reader :plans, :report, :seen

      def marker(index:, data:)
        report.record(index: index, data: data)
        nil
      end

      def build(plan:, data:)
        unit, kind = locate(plan: plan, data: data)
        found = unit ? plan.units[unit] : nil
        ident = data["SYSLOG_IDENTIFIER"].to_s
        found ||= plan.identifiers[ident]
        found ||= { name: (data["_SYSTEMD_USER_UNIT"] || data["_SYSTEMD_UNIT"] || ident).to_s.sub(/\.service\z/, ""), color: 37 }
        @order += 1
        Hatchbox::Logs::Entry.new(
          time: time_of(data),
          source: kind || "app",
          label: found[:name],
          message: message_of(data["MESSAGE"]),
          color: found[:color],
          order: @order
        )
      end

      def locate(plan:, data:)
        found = [data["_SYSTEMD_USER_UNIT"], data["_SYSTEMD_UNIT"]].find { |unit| plan.units.key?(unit) }
        return [found, "app"] if found

        found = [data["USER_UNIT"], data["UNIT"]].find { |unit| plan.units.key?(unit) }
        return [found, "systemd"] if found

        [nil, nil]
      end

      def time_of(data)
        micros = data["__REALTIME_TIMESTAMP"].to_i
        Time.at(micros / 1_000_000, micros % 1_000_000, :usec).utc
      end

      def message_of(value)
        text = value.is_a?(Array) ? value.pack("C*").force_encoding(Encoding::UTF_8).scrub : value.to_s
        text.chomp
      end
    end
  end
end
