# frozen_string_literal: true

module Hatchbox
  module Logs
    class Report
      QUIET_EXITS = [0, 130, 143].freeze

      def initialize(plans:)
        @plans = plans
        @live = {}
        @missing = []
        @found = Hash.new { |hash, key| hash[key] = [] }
        @blind = []
      end

      def record(index:, data:)
        case data["__hbx"]
        when "live" then live[index] = true
        when "missing" then missing << [plans[index].target.label, data["unit"]]
        when "unit" then found[index] << "#{data["unit"]} (#{data["scope"]})"
        when "blind" then blind << plans[index].target.label
        end
      end

      def live?(index)
        live[index]
      end

      def print_units
        plans.each_with_index do |plan, index|
          Hatchbox::Ui.header("#{plan.target.label} (#{plan.target.host})")
          found[index].each { |line| puts(line) }
          missing.select { |label, _unit| label == plan.target.label }.each { |_label, unit| puts("#{unit} (not on this server)") }
          plan.identifiers.each_key { |name| puts("#{name} (identifier)") }
          puts
        end
      end

      def finish(exits:)
        warn_gaps
        failed = exits.reject { |_index, code| QUIET_EXITS.include?(code) }
        return 0 if failed.empty? || failed.length < plans.length
        raise Hatchbox::Error, "No systemd unit to read. Try hatchbox logs --units to see what it looked for." if failed.values.uniq == [3]

        failed.values.first
      end

      private

      attr_reader :plans, :live, :missing, :found, :blind

      def warn_gaps
        missing.each { |label, unit| Hatchbox::Ui.warning("There is no #{unit} on #{label}.") }
        blind.uniq.each do |label|
          Hatchbox::Ui.warning("The SSH user on #{label} cannot read the system journal. Add it to the systemd-journal group to see those lines.")
        end
      end
    end
  end
end
