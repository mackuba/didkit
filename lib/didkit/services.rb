# frozen_string_literal: true

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

    # Returns the PDS service endpoint, if present and valid.
    #
    # If the DID has an `#atproto_pds` service declared in its `service` section,
    # returns the URL in its `serviceEndpoint` field. In other words, this is the URL
    # of the PDS assigned to a given user, which stores the user's account and repo.
    #
    # Returns nil if the service record is present, but the URL is not a valid HTTP(S) URL.
    # For PDS endpoint specifically, the URL should only contain the scheme, hostname, and
    # optional port number, but no userinfo, path, query or other components. As an exception,
    # a path in the form of a single trailing slash is also allowed.
    #
    # @api public
    # @return [String, nil] PDS service endpoint URL

    def pds_endpoint
      return @pds_endpoint if @pds_endpoint

      endpoint = get_service('atproto_pds', 'AtprotoPersonalDataServer')&.endpoint
      return nil if endpoint.nil?

      uri = URI(endpoint)

      return nil if uri.scheme !~ /^https?$/ || uri.host.nil? || uri.host.empty?
      return nil if uri.userinfo || uri.query || uri.fragment
      return nil unless uri.path.empty? || uri.path == '/'

      @pds_endpoint = endpoint
    end

    # Returns the labeler service endpoint, if present and valid.
    #
    # If the DID has an `#atproto_labeler` service declared in its `service` section,
    # returns the URL in its `serviceEndpoint` field.
    #
    # Returns nil if the service record is present, but the URL is not an HTTP(S) URL.
    #
    # @api public
    # @return [String, nil] labeler service endpoint URL

    def labeler_endpoint
      return @labeler_endpoint if @labeler_endpoint

      endpoint = get_service('atproto_labeler', 'AtprotoLabeler')&.endpoint
      return nil if endpoint.nil?

      uri = URI(endpoint)
      return nil if uri.scheme !~ /^https?$/ || uri.host.nil? || uri.host.empty?

      @labeler_endpoint = endpoint
    end

    # Returns the hostname of the PDS service, if present.
    #
    # If the endpoint URL includes a port number, it is excluded.
    #
    # @api public
    # @return [String, nil] hostname of the PDS endpoint URL

    def pds_host
      pds_endpoint&.then { |x| URI(x).host }
    end

    # Returns the hostname of the labeler service, if present.
    #
    # If the endpoint URL includes a port number, it is excluded.
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
