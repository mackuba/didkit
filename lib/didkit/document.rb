require_relative 'at_handles'
require_relative 'resolver'
require_relative 'service_record'
require_relative 'services'

module DIDKit
  class Document
    class FormatError < StandardError
    end

    include AtHandles
    include Services

    attr_reader :json, :did, :handles, :services

    def initialize(did, json)
      raise FormatError, "Missing id field" if json['id'].nil?
      raise FormatError, "Invalid id field" unless json['id'].is_a?(String)
      raise FormatError, "id field doesn't match expected DID" unless json['id'] == did.to_s

      @did = did
      @json = json

      if service = json['service']
        raise FormatError, "Invalid service data" unless service.is_a?(Array) && service.all? { |x| x.is_a?(Hash) }

        @services = service.filter_map { |x|
          id, type, endpoint = x.values_at('id', 'type', 'serviceEndpoint')
          next unless id.is_a?(String) && id.start_with?('#') && type.is_a?(String) && endpoint.is_a?(String)

          ServiceRecord.new(id.gsub(/^#/, ''), type, endpoint)
        }
      else
        @services = []
      end

      @handles = parse_also_known_as(json['alsoKnownAs'] || [])
    end

    def get_validated_handle
      Resolver.new.pick_valid_handle(did, handles)
    end
  end
end
