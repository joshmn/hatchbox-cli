# frozen_string_literal: true

module Hatchbox
  class Docs
    def initialize(dir:)
      @dir = dir
    end

    def pages
      commands = Hatchbox::Registry.commands.reject { |klass| Hatchbox::Registry.source_of(klass) }
      commands.group_by { |klass| klass.meta[:name].split(":").first }.sort.to_h do |topic, members|
        [File.join(dir, "#{topic}.md"), page(topic: topic, members: members.sort_by { |klass| klass.meta[:name] })]
      end
    end

    def write
      FileUtils.mkdir_p(dir)
      pages.each { |path, body| File.write(path, body) }
    end

    private

    attr_reader :dir

    def page(topic:, members:)
      out = ["# hatchbox #{topic}", ""]
      summary = Hatchbox::Help.topics[topic]
      out.push(summary, "") if summary
      members.each { |klass| out << "* [`hatchbox #{klass.meta[:name]}`](##{anchor(klass)})" }
      members.each { |klass| out.push("", *section(klass)) }
      out.join("\n") + "\n"
    end

    def section(klass)
      meta = klass.meta
      out = ["## hatchbox #{meta[:name]}", "", "#{Hatchbox::Help.summary(klass).sub(/\A./) { |first| first.upcase }}.", "", "```", "Usage: hatchbox #{meta[:usage]}"]
      flags = (meta[:app] ? Hatchbox::Command::APP_FLAGS.map { |spec| Hatchbox::Flag.new(spec) } : []) + meta[:flags]
      if flags.any?
        width = flags.map { |flag| flag.label.length }.max
        out.push("", "Flags:", *flags.map { |flag| "  #{flag.label.ljust(width)}  #{flag.description}" })
      end
      out.push("```")
      out.concat(prose(Array(meta[:help]))) if meta[:help]
      out.push("", Hatchbox::Help::Page::SSH_NOTES.fetch(meta[:ssh]).join(" ")) if meta[:ssh]
      out.push("", "Aliases: #{meta[:aliases].map { |name| "`#{name}`" }.join(", ")}") if meta[:aliases].any?
      out.push("", "Examples:", "", "```", *meta[:examples], "```") if meta[:examples].any?
      out
    end

    def prose(lines)
      lines.slice_when { |a, b| a.empty? || b.empty? }.reject { |chunk| chunk == [""] }.flat_map do |chunk|
        chunk.first.start_with?("  ") ? ["", "```", *chunk.map { |line| line.delete_prefix("  ") }, "```"] : ["", chunk.join(" ")]
      end
    end

    def anchor(klass)
      "hatchbox-#{klass.meta[:name]}".downcase.gsub(/[^a-z0-9 _-]/, "").tr(" ", "-")
    end
  end
end
