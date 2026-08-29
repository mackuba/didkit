# frozen_string_literal: true

require_relative 'at_handles'
require_relative 'errors'
require_relative 'public_key'
require_relative 'resolver'
require_relative 'service_record'
require_relative 'services'

module DIDKit

  #
  # Parsed DID document from a JSON file loaded from [plc.directory](https://plc.directory) or a did:web domain.
  #
  # Use {DID#document} or {Resolver#resolve_did} to fetch a DID document and return this object.
  #
  # Related specifications:
  # - [ATProto DID](https://atproto.com/specs/did)
  #

  class Document
    include AtHandles
    include Services

    # @return [Hash] the complete JSON data of the DID document
    attr_reader :json

    # @return [DID] the DID that this document describes
    attr_reader :did

    # @return [Array<ServiceRecords>] service records like PDS details assigned to the DID
    attr_reader :services

    # Creates a DID document object.
    #
    # @param did [DID] DID object
    # @param json [Hash] DID document JSON
    # @raise [FormatError] when required fields are missing or invalid.

    def initialize(did, json)
      raise FormatError, "Missing id field" if json['id'].nil?
      raise FormatError, "Invalid id field" unless json['id'].is_a?(String)
      raise FormatError, "id field doesn't match expected DID" unless json['id'] == did.to_s

      @did = did
      @json = json

      parse_services(json['service'] || [])
      parse_also_known_as(json['alsoKnownAs'] || [])
    end

    # Returns the current primary handle assigned to the DID, if it verifies correctly.
    #
    # Looks up the first syntactically valid handle in the DID document and checks if it is assigned
    # correctly to this DID using DNS TXT or .well-known. Any later handles are ignored, even if the
    # first handle fails verification. Returns nil if the primary handle cannot be verified.
    #
    # @return [String, nil] verified handle domain, if found

    def get_verified_handle
      Resolver.new.get_verified_handle(self)
    end

    # Returns the account's public signing key parsed from the DID document's `verificationMethod`.
    #
    # @return [PublicKey, nil] decoded signing key wrapped in {PublicKey}, or nil if no matching verification method is found
    # @raise [FormatError] when `verificationMethod` or one of its entries has an invalid type
    # @raise [ArgumentError] when selected key data is not a string
    # @raise [KeyError] when the key is invalid, incorrectly encoded, or has unsupported type

    def signing_key
      keys = @json['verificationMethod']
      return nil if keys.nil?

      raise FormatError, "verificationMethod is not an array: #{keys.inspect}" unless keys.is_a?(Array)

      keys.each do |data|
        raise FormatError, "verificationMethod item is invalid: #{data.inspect}" unless data.is_a?(Hash)

        next unless data['id'] == "#{@did}#atproto" || data['id'] == "#atproto"
        next unless data['controller'] == @did.to_s && data['type'] == 'Multikey' && !data['publicKeyMultibase'].nil?

        return PublicKey.new(data['publicKeyMultibase'])
      end

      nil
    end


    private

    def parse_services(service_data)
      raise FormatError, "Invalid service data" unless service_data.is_a?(Array) && service_data.all? { |x| x.is_a?(Hash) }

      @services = []

      service_data.each do |x|
        id, type, endpoint = x.values_at('id', 'type', 'serviceEndpoint')

        raise FormatError, "Missing service id" unless id
        raise FormatError, "Invalid service id: #{id.inspect}" unless id.is_a?(String)
        next if !id.start_with?('#')

        raise FormatError, "Missing service type" unless type
        raise FormatError, "Invalid service type: #{type.inspect}" unless type.is_a?(String)

        raise FormatError, "Missing service endpoint" unless endpoint
        raise FormatError, "Invalid service endpoint: #{endpoint.inspect}" unless endpoint.is_a?(String)

        begin
          @services << ServiceRecord.new(id.gsub(/^#/, ''), type, endpoint)
        rescue FormatError => e
          # ignore services with invalid URIs
        end
      end
    end
  end
end
