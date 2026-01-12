require 'uri'

module DIDKit

  #
  # @api private
  #

  module Services

    # Finds a service entry matching the given key and type.
    #
    # @api public
    # @param key [String] service key in the DID document
    # @param type [String] service type identifier
    # @return [ServiceRecord, nil] matching service record, if found

    def get_service(key, type)
      @services&.detect { |s| s.key == key && s.type == type }
    end

    # Returns the PDS service endpoint, if present.
    #
    # If the DID has an `#atproto_pds` service declared in its `service` section,
    # returns the URL in its `serviceEndpoint` field. In other words, this is the URL
    # of the PDS assigned to a given user, which stores the user's account and repo.
    #
    # @api public
    # @return [String, nil] PDS service endpoint URL

    def pds_endpoint
      @pds_endpoint ||= get_service('atproto_pds', 'AtprotoPersonalDataServer')&.endpoint
    end

    # Returns the labeler service endpoint, if present.
    #
    # If the DID has an `#atproto_labeler` service declared in its `service` section,
    # returns the URL in its `serviceEndpoint` field.
    #
    # @api public
    # @return [String, nil] labeler service endpoint URL

    def labeler_endpoint
      @labeler_endpoint ||= get_service('atproto_labeler', 'AtprotoLabeler')&.endpoint
    end

    # Returns the hostname of the PDS service, if present.
    #
    # @api public
    # @return [String, nil] hostname of the PDS endpoint URL

    def pds_host
      pds_endpoint&.then { |x| URI(x).host }
    end

    # Returns the hostname of the labeler service, if present.
    #
    # @api public
    # @return [String, nil] hostname of the labeler endpoint URL

    def labeler_host
      labeler_endpoint&.then { |x| URI(x).host }
    end

    alias labeller_endpoint labeler_endpoint
    alias labeller_host labeler_host
  end
end
