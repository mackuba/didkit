require 'uri'
require_relative 'errors'

module DIDKit
  class ServiceRecord
    attr_reader :key, :type, :endpoint

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
