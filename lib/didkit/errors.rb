module DIDKit
  # Base error for DIDKit operations.
  class DIDError < StandardError
  end

  # Error raised when an HTTP API request returns an unexpected response.
  class APIError < StandardError
    attr_reader :response

    # Create an APIError wrapping the failed response.
    #
    # @param response [Net::HTTPResponse] HTTP response object.
    def initialize(response)
      @response = response
      super("APIError: #{response}")
    end

    # Return HTTP status code as an integer.
    #
    # @return [Integer] HTTP status code.
    def status
      response.code.to_i
    end

    # Return HTTP response body.
    #
    # @return [String, nil] response body.
    def body
      response.body
    end
  end
end
