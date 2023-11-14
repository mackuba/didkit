module DIDKit
  class Document
    attr_reader :json

    def initialize(json)
      @json = json
    end

    def pds_endpoint
      service = (@json['service'] || []).detect { |s| s['id'] == '#atproto_pds' }
      service && service['serviceEndpoint']
    end
  end
end
