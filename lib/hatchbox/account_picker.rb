# frozen_string_literal: true

module Hatchbox
  class AccountPicker
    def initialize(accounts:, usable:)
      @accounts = accounts
      @usable = usable
    end

    def pick(wanted)
      return only_usable if Hatchbox.blank?(wanted)

      found = accounts.find do |account|
        [account["id"].to_s, "acct_#{account["id"]}"].include?(wanted.to_s) || account["name"].to_s.casecmp?(wanted.to_s)
      end
      raise Hatchbox::Error, "Couldn't find that team." unless found

      found
    end

    private

    attr_reader :accounts, :usable

    def only_usable
      return usable.first if usable.length == 1
      raise Hatchbox::Error, "Your token can reach no account with an active subscription." if usable.empty?

      raise Hatchbox::Error, (["Pick an account with --team:"] + usable.map { |account| "#{account["name"]} (#{account["id"]})" }).join("\n")
    end
  end
end
