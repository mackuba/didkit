# frozen_string_literal: true

require_relative 'at_handles'
require_relative 'errors'
require_relative 'resolver'
require_relative 'service_record'
require_relative 'services'

module DIDKit

  #
  # Parsed DID document from a JSON file loaded from [plc.directory](https://plc.directory) or a did:web domain.
  #
  # Use {DID#document} or {Resolver#resolve_did} to fetch a DID document and return this object.
  #

  class Document
    include AtHandles
    include Services

    # @return [Hash] the complete JSON data of the DID document
    attr_reader :json

    # @return [DID] the DID that this document describes
    attr_reader :did

    # Returns a list of handles assigned to this DID in its DID document.
    #
    # Note: the handles aren't guaranteed to be verified (validated in the other direction).
    # Use {#get_verified_handle} to find a handle that is correctly verified.
    #
    # @return [Array<String>]
    attr_reader :handles

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

      @services = parse_services(json['service'] || [])
      @handles = parse_also_known_as(json['alsoKnownAs'] || [])
    end

    # Returns the first verified handle assigned to the DID.
    #
    # Looks up the domain handles assigned to this DID in the DID document, checks if they are
    # verified (i.e. assigned correctly to this DID using DNS TXT or .well-known) and returns
    # the first handle that validates correctly, or nil if none matches.
    #
    # @return [String, nil] verified handle domain, if found

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
