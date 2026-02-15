# frozen_string_literal: true

require 'time'

require_relative 'at_handles'
require_relative 'errors'
require_relative 'service_record'
require_relative 'services'

module DIDKit

  #
  # Represents a single operation of changing a specific DID's data in the [plc.directory](https://plc.directory)
  # (e.g. changing assigned handles or migrating to a different PDS).
  #

  class PLCOperation
    include AtHandles
    include Services

    # @return [Hash] the JSON from which the operation is parsed
    attr_reader :json

    # @return [String] the DID which the operation concerns
    attr_reader :did

    # @return [String] CID (Content Identifier) of the operation
    attr_reader :cid

    # Returns a sequential number of the operation (only used in the new export API).
    # @return [Integer, nil] sequential number of the operation
    attr_reader :seq

    # @return [Time] time when the operation was created
    attr_reader :created_at

    # Returns the `type` field of the operation (usually `"plc_operation"`).
    # @return [String] the operation type
    attr_reader :type

    # Returns a list of handles assigned to the DID in this operation.
    #
    # Note: the handles aren't guaranteed to be verified (validated in the other direction).
    # Use {DID#get_verified_handle} or {Document#get_verified_handle} to find a handle that is
    # correctly verified.
    #
    # @return [Array<String>]
    attr_reader :handles

    # @return [Array<ServiceRecords>] service records like PDS details assigned to the DID
    attr_reader :services


    # Creates a PLCOperation object.
    #
    # @param json [Hash] operation JSON
    # @raise [FormatError] when required fields are missing or invalid

    def initialize(json)
      @json = json
      raise FormatError, "Expected argument to be a Hash, got a #{json.class}" unless @json.is_a?(Hash)

      @seq = json['seq']
      @did = json['did']
      raise FormatError, "Missing DID: #{json}" if @did.nil?
      raise FormatError, "Invalid DID: #{@did.inspect}" unless @did.is_a?(String) && @did.start_with?('did:')

      @cid = json['cid']
      raise FormatError, "Missing CID: #{json}" if @cid.nil?
      raise FormatError, "Invalid CID: #{@cid}" unless @cid.is_a?(String)

      timestamp = json['createdAt']
      raise FormatError, "Missing createdAt: #{json}" if timestamp.nil?
      raise FormatError, "Invalid createdAt: #{timestamp.inspect}" unless timestamp.is_a?(String)

      @created_at = Time.parse(timestamp)

      operation = json['operation']
      raise FormatError, "Missing operation key: #{json}" if operation.nil?
      raise FormatError, "Invalid operation data: #{operation.inspect}" unless operation.is_a?(Hash)

      type = operation['type']
      raise FormatError, "Missing operation type: #{json}" if type.nil?

      @type = type.to_sym
      return unless @type == :plc_operation

      services = operation['services']
      raise FormatError, "Missing services key: #{json}" if services.nil?
      raise FormatError, "Invalid services data: #{services}" unless services.is_a?(Hash)

      @services = services.map { |k, x|
        type, endpoint = x.values_at('type', 'endpoint')

        raise FormatError, "Missing service type" unless type
        raise FormatError, "Invalid service type: #{type.inspect}" unless type.is_a?(String)
        raise FormatError, "Missing service endpoint" unless endpoint
        raise FormatError, "Invalid service endpoint: #{endpoint.inspect}" unless endpoint.is_a?(String)

        ServiceRecord.new(k, type, endpoint)
      }

      @handles = parse_also_known_as(operation['alsoKnownAs'])
    end
  end
end
