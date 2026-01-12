require 'uri'

module DIDKit
  # Extracts service endpoints from parsed DID documents.
  module Services
    # Find a service entry by key and type.
    #
    # @param key [String] service key in the DID document.
    # @param type [String] service type identifier.
    # @return [ServiceRecord, nil] the matching service record.
    def get_service(key, type)
      @services&.detect { |s| s.key == key && s.type == type }
    end

    # Return the PDS service endpoint, if present.
    #
    # @return [String, nil] PDS service endpoint URL.
    def pds_endpoint
      @pds_endpoint ||= get_service('atproto_pds', 'AtprotoPersonalDataServer')&.endpoint
    end

    # Return the labeler service endpoint, if present.
    #
    # @return [String, nil] labeler service endpoint URL.
    def labeler_endpoint
      @labeler_endpoint ||= get_service('atproto_labeler', 'AtprotoLabeler')&.endpoint
    end

    # Return the PDS host, if present.
    #
    # @return [String, nil] PDS host extracted from the endpoint URL.
    def pds_host
      pds_endpoint&.then { |x| URI(x).host }
    end

    # Return the labeler host, if present.
    #
    # @return [String, nil] labeler host extracted from the endpoint URL.
    def labeler_host
      labeler_endpoint&.then { |x| URI(x).host }
    end

    alias labeller_endpoint labeler_endpoint
    alias labeller_host labeler_host
  end
end
