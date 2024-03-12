require_relative 'resolver'

module DIDKit
  class Document
    class FormatError < StandardError
    end

    attr_reader :json, :did, :pds_endpoint, :handles

    def initialize(did, json)
      raise FormatError, "Missing id field" if json['id'].nil?
      raise FormatError, "Invalid id field" unless json['id'].is_a?(String)
      raise FormatError, "id field doesn't match expected DID" unless json['id'] == did.to_s

      @did = did
      @json = json

      service = json['service']
      raise FormatError, "Missing service key" if service.nil?
      raise FormatError, "Invalid service data" unless service.is_a?(Array) && service.all? { |x| x.is_a?(Hash) }

      if pds = service.detect { |x| x['id'] == '#atproto_pds' }
        raise FormatError, "Missing PDS type" unless pds['type']
        raise FormatError, "Invalid PDS type" unless pds['type'] == 'AtprotoPersonalDataServer'
        raise FormatError, "Missing PDS endpoint" unless pds['serviceEndpoint']
        raise FormatError, "Invalid PDS endpoint" unless pds['serviceEndpoint'].is_a?(String)
        raise FormatError, "Invalid PDS endpoint" unless pds['serviceEndpoint'] =~ %r(://)

        @pds_endpoint = pds['serviceEndpoint']
      end

      if aka = json['alsoKnownAs']
        raise FormatError, "Invalid alsoKnownAs" unless aka.is_a?(Array)
        raise FormatError, "Invalid alsoKnownAs" unless aka.all? { |x| x.is_a?(String) }
        raise FormatError, "Invalid alsoKnownAs" unless aka.all? { |x| x =~ %r(\Aat://[^/]+\z) }

        @handles = aka.map { |x| x.gsub('at://', '') }
      else
        @handles = []
      end
    end

    def get_validated_handle
      Resolver.new.pick_valid_handle(did, handles)
    end
  end
end
