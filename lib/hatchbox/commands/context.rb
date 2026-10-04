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

      def ssh_target(dyno: nil, server: nil)
        Hatchbox::SshTarget.new(session: session, server: dyno_server(dyno: dyno, server: server))
      end

      def dyno_server(dyno:, server:)
        return nil if Hatchbox::SshTarget.pinned?(session)
        return app.formation.find_dyno(dyno).server unless Hatchbox.blank?(dyno)

        app.fleet.find_server(server)
      end
    end
  end
end
