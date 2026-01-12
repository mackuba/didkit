require 'uri'
require_relative 'errors'

module DIDKit

  # A parsed service record from either a DID document's `service` field or a PLC directory
  # operation's `services` field.

  class ServiceRecord

    # Returns the service's identifier (without `#`), like "atproto_pds".
    # @return [String] service's identifier
    attr_reader :key

    # Returns the service's type field, like "AtprotoPersonalDataServer".
    # @return [String] service's type
    attr_reader :type

    # @return [String] service's endpoint URL
    attr_reader :endpoint

    # Create a service record from DID document fields.
    #
    # @param key [String] service identifier (without `#`)
    # @param type [String] service type
    # @param endpoint [String] service endpoint URL
    # @raise [FormatError] when the endpoint is not a valid URI

    def initialize(key, type, endpoint)
      begin
        uri = URI(endpoint)
      rescue URI::Error
        raise FormatError, "Invalid service endpoint: #{endpoint.inspect}"
      end

      @key = key
      @type = type
      @endpoint = endpoint
    end
  end
end
