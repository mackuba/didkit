module DIDKit
  class DIDError < StandardError
  end

  class APIError < StandardError
    attr_reader :response

    def initialize(response)
      @response = response
      super("APIError: #{response}")
    end

    def status
      response.code.to_i
    end

    def body
      response.body
    end
  end
end
