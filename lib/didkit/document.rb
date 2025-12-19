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

      @services = parse_services(json['service'] || [])
      @handles = parse_also_known_as(json['alsoKnownAs'] || [])
    end

    def get_verified_handle
      Resolver.new.get_verified_handle(self)
    end

    private

    def parse_services(service_data)
      raise FormatError, "Invalid service data" unless service_data.is_a?(Array) && service_data.all? { |x| x.is_a?(Hash) }

      services = []

      service_data.each do |x|
        id, type, endpoint = x.values_at('id', 'type', 'serviceEndpoint')

        if id.is_a?(String) && id.start_with?('#') && type.is_a?(String) && endpoint.is_a?(String)
          services << ServiceRecord.new(id.gsub(/^#/, ''), type, endpoint)
        end
      end

      services
    end
  end
end
