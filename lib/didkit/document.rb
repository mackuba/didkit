require_relative 'resolver'
require_relative 'service_record'
require_relative 'services'

module DIDKit
  class Document
    class FormatError < StandardError
    end

    include Services

    attr_reader :json, :did, :handles, :services

    def initialize(did, json)
      raise FormatError, "Missing id field" if json['id'].nil?
      raise FormatError, "Invalid id field" unless json['id'].is_a?(String)
      raise FormatError, "id field doesn't match expected DID" unless json['id'] == did.to_s

      @did = did
      @json = json

      service = json['service']
      raise FormatError, "Missing service key" if service.nil?
      raise FormatError, "Invalid service data" unless service.is_a?(Array) && service.all? { |x| x.is_a?(Hash) }

      @services = service.map { |x|
        id, type, endpoint = x.values_at('id', 'type', 'serviceEndpoint')

        raise FormatError, "Missing service id" unless id
        raise FormatError, "Invalid service id: #{id.inspect}" unless id.is_a?(String) && id.start_with?('#')
        raise FormatError, "Missing service type" unless type
        raise FormatError, "Invalid service type: #{type.inspect}" unless type.is_a?(String)
        raise FormatError, "Missing service endpoint" unless endpoint
        raise FormatError, "Invalid service endpoint: #{endpoint.inspect}" unless endpoint.is_a?(String)

        ServiceRecord.new(id.gsub(/^#/, ''), type, endpoint)
      }

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
