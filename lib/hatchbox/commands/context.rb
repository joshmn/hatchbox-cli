# frozen_string_literal: true

module Hatchbox
  module Commands
    module Context
      private

      def client
        session.client
      end

      def app
        session.app
      end

      def app_id
        session.app_id
      end

      def config
        session.config
      end

      def env
        session.env
      end

      def prompt
        session.prompt
      end

      def label
        app.label
      end

      def ssh_target(server: nil)
        picked = Hatchbox::SshTarget.pinned?(session) ? nil : app.fleet.find_server(server)
        Hatchbox::SshTarget.new(session: session, server: picked)
      end
    end
  end
end
