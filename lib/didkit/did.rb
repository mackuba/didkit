require_relative 'errors'
require_relative 'resolver'

module DIDKit
  class DID
    def self.resolve_handle(handle)
      Resolver.new.resolve_handle(handle)
    end

    attr_reader :type, :did, :resolved_by

    def initialize(did, resolved_by = nil)
      if did =~ /^did\:(\w+)\:/
        @did = did
        @type = $1.to_sym
      else
        raise DIDError.new("Invalid DID format")
      end

      if @type != :plc && @type != :web
        raise DIDError.new("Unrecognized DID type: #{@type}")
      end

      @resolved_by = resolved_by
    end

    alias to_s did

    def get_document
      Resolver.new.resolve_did(self)
    end

    def get_validated_handle
      Resolver.new.get_validated_handle(self)
    end

    def web_domain
      did.gsub(/^did\:web\:/, '') if type == :web
    end

    def ==(other)
      if other.is_a?(String)
        self.did == other
      elsif other.is_a?(DID)
        self.did == other.did
      else
        false
      end
    end
  end
end
