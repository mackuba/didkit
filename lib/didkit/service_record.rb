require 'uri'
require_relative 'errors'

module DIDKit
  # Represents a service entry within a DID document.
  class ServiceRecord
    # Raised when a service endpoint URI is invalid.
    class FormatError < StandardError
    end

    attr_reader :key, :type, :endpoint

    # Create a service record from DID document fields.
    #
    # @param key [String] service identifier.
    # @param type [String] service type.
    # @param endpoint [String] service endpoint URL.
    # @raise [FormatError] when the endpoint is not a valid URI.
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
