# frozen_string_literal: true

module Hatchbox
  module Commands
    module Ps
      class Copy < Hatchbox::Command
        describe "ps:copy",
          summary: "copy a file off one of the app's servers",
          usage: "ps:copy FILE",
          args: { file: "FILE" },
          ssh: :shell,
          flags: [
            ["-o", "--output FILE", "where to write it, the file's own name unless you say otherwise"],
            ["-s", "--server SERVER", "the server, by name, id or role"]
          ],
          help: ["A relative FILE is read from the app's current release."],
          examples: ["$ hatchbox ps:copy log/production.log", "Copying log/production.log to production.log... done"]

        def call
          file = args.file
          output = options.output || File.basename(file)
          raise Hatchbox::Error, "#{output} already exists. Pick another name with --output." if File.exist?(output) && options.output.nil?

          target = ssh_target(server: options.server)
          remote = file.start_with?("/") || target.app_dir.nil? ? file : File.join(target.app_dir, file)
          argv = ["scp", "-q", "-P", target.port.to_s] + Hatchbox.ssh_options + ["#{target.address}:#{Shellwords.escape(remote)}", output]
          code = nil
          ui.action("Copying #{file} to #{output}") do |step|
            code = Hatchbox.run(argv)
            step.status = code.zero? ? "done" : ui.paint("failed", code: 31)
          end
          code
        end
      end
    end
  end
end
