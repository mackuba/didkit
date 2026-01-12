module DIDKit

  #
  # Raised when an HTTP request returns a response with an error status.
  #
  class APIError < StandardError

    # @return [Net::HTTPResponse] the returned HTTP response
    attr_reader :response

    # @param response [Net::HTTPResponse] the returned HTTP response
    def initialize(response)
      @response = response
      super("APIError: #{response}")
    end

    # @return [Integer] HTTP status code
    def status
      response.code.to_i
    end

    # @return [String] HTTP response body
    def body
      response.body
    end
  end

  #
  # Raised when a string is not a valid DID or not of the right type.
  #
  class DIDError < StandardError
  end

  #
  # Raised when the loaded data has some missing or invalid fields.
  #
  class FormatError < StandardError
  end
end
