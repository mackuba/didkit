# frozen_string_literal: true

require_relative "didkit/did"
require_relative "didkit/document"
require_relative "didkit/plc_importer"
require_relative "didkit/plc_operation"
require_relative "didkit/resolver"
require_relative "didkit/version"

module DIDKit
  class << self
    # Default shared resolver used when calling {DID}/{Document} methods directly.
    # @return [DIDKit::Resolver]
    attr_accessor :default_resolver
  end

  self.default_resolver = Resolver.new
end

DID = DIDKit::DID
