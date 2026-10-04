# frozen_string_literal: true

module Hatchbox
  module Logs
    class Reader
      def initialize(plans:, lines:, follow:, since:, source:, units_only:, colors:)
        @plans = plans
        @lines = lines
        @follow = follow
        @since = since
        @source = source
        @units_only = units_only
        @colors = colors
        @connections = Hatchbox::Logs::Connections.new
        @closed = {}
        @exits = {}
        @report = Hatchbox::Logs::Report.new(plans: plans)
        @parser = Hatchbox::Logs::Parser.new(plans: plans, report: report)
      end

      def run
        plans.each_with_index { |plan, index| start_journal(plan: plan, index: index) }
        backlog = collect
        return units_status if units_only

        print_entries(backlog.sort_by { |entry| [entry.time, entry.order] }.last(lines))
        stream if follow
        report.finish(exits: exits)
      ensure
        connections.close
      end

      private

      attr_reader :plans, :lines, :follow, :since, :source, :units_only, :colors, :connections, :closed, :exits, :report, :parser

      def start_journal(plan:, index:)
        depth = Hatchbox.blank?(source) ? lines : [lines * 50, 10_000].min
        journal = plan.journal(lines: depth, follow: follow, since: since, units_only: units_only)
        connections.open(target: plan.target, script: journal.script, index: index)
      end

      def collect
        entries = []
        until plans.each_index.all? { |index| settled?(index) }
          entry = next_entry
          entries << entry if entry
        end
        entries
      end

      def stream
        until plans.each_index.all? { |index| done?(index) }
          entry = next_entry
          print_entries([entry]) if entry
        end
      end

      def next_entry
        kind, index, payload = connections.pop
        return wanted(parser.parse(index: index, text: payload)) if kind == :line

        record(kind: kind, index: index, payload: payload)
        nil
      end

      def record(kind:, index:, payload:)
        case kind
        when :err then $stderr.print(plans.length > 1 ? "#{plans[index].target.label}: #{payload}" : payload)
        when :eof then closed[index] = true
        when :exit then exits[index] = payload
        end
      end

      def done?(index)
        exits.key?(index) && closed[index]
      end

      def settled?(index)
        return true if done?(index)
        return false unless follow

        report.live?(index)
      end

      def wanted(entry)
        entry if entry && (Hatchbox.blank?(source) || entry.source == source)
      end

      def print_entries(entries)
        entries.each { |entry| $stdout.puts(entry.line(colors: colors)) }
        $stdout.flush
      end

      def units_status
        report.print_units
        exits.values.all? { |code| code.zero? } ? 0 : 1
      end
    end
  end
end
