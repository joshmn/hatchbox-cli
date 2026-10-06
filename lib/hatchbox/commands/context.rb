# frozen_string_literal: true

module Hatchbox
  module Commands
    module Context
      private

      [:client, :app, :app_id, :config, :prompt].each { |name| define_method(name) { session.public_send(name) } }

      { ui: Hatchbox::Ui, printer: Hatchbox::Printer, formatter: Hatchbox::Formatter, color: Hatchbox::Color }.each do |name, helper|
        define_method(name) { helper }
      end

      def label
        app.label
      end

      def account
        @account ||= session.catalog.account_for(app_id)
        raise Hatchbox::Error, "Could not tell which account #{label} is on." unless @account

        @account
      end

      def json?
        options.key?(:json)
      end

      def print_json(data)
        puts(JSON.pretty_generate(data))
        0
      end

      def ssh_target(server: nil)
        Hatchbox::SshTarget.for(session) { app.fleet.find_server(server) }
      end
    end
  end
end
