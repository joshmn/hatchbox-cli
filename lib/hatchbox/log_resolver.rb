# frozen_string_literal: true

module Hatchbox
  class LogResolver
    NAMES = {
      "deploy" => "Apps::Deploy",
      "deploys" => "Apps::Deploy",
      "restart" => "Apps::Restart",
      "restarts" => "Apps::Restart"
    }.freeze

    def initialize(client:, app_id:, label:)
      @client = client
      @app_id = app_id
      @label = label
    end

    def resolve(wanted, kind: nil)
      text = wanted.to_s
      return text if text =~ /\A[0-9]+\z/

      name = Hatchbox.blank?(text) ? kind : NAMES[text]
      raise Hatchbox::Error, "#{text} is not a release id, deploy or restart. hatchbox releases lists the ids." if !Hatchbox.blank?(text) && name.nil?

      rows = client.get("/apps/#{app_id}/logs?limit=100").json || []
      found = name ? rows.find { |row| row["name"] == name } : rows.first
      raise Hatchbox::Error, "#{label} has no #{missing_noun(name)} on record." unless found

      found["id"].to_s
    end

    private

    attr_reader :client, :app_id, :label

    def missing_noun(name)
      name ? Hatchbox::Activity.humanize(name).downcase : "releases"
    end
  end
end
