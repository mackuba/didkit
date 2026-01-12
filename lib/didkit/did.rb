require 'json'
require 'uri'

require_relative 'errors'
require_relative 'requests'
require_relative 'resolver'

module DIDKit
  # Represents a DID identifier and provides related lookup helpers.
  class DID
    GENERIC_REGEXP = /\Adid\:\w+\:.+\z/

    include Requests

    # Resolve a handle into a DID.
    #
    # @param handle [String] handle or DID string.
    # @return [DID, nil] resolved DID if found.
    def self.resolve_handle(handle)
      Resolver.new.resolve_handle(handle)
    end

    attr_reader :type, :did, :resolved_by

    # Create a DID object from a string or DID instance.
    #
    # @param did [String, DID] DID string or DID object.
    # @param resolved_by [Symbol, nil] resolution source (e.g. :dns, :http).
    # @raise [DIDError] when the DID format or type is invalid.
    def initialize(did, resolved_by = nil)
      if did.is_a?(DID)
        did = did.to_s
      end

      if did =~ GENERIC_REGEXP
        @did = did
        @type = did.split(':')[1].to_sym
      else
        raise DIDError.new("Invalid DID format")
      end

      if @type != :plc && @type != :web
        raise DIDError.new("Unrecognized DID type: #{@type}")
      end

      @resolved_by = resolved_by
    end

    alias to_s did

    # Return the cached DID document.
    #
    # @return [Document] resolved DID document.
    def document
      @document ||= get_document
    end

    # Resolve the DID document.
    #
    # @return [Document] resolved DID document.
    def get_document
      Resolver.new.resolve_did(self)
    end

    # Return the first verified handle for this DID.
    #
    # @return [String, nil] verified handle if found.
    def get_verified_handle
      Resolver.new.get_verified_handle(document)
    end

    # Fetch the PLC audit log for this DID.
    #
    # @return [Array<Hash>] audit log entries.
    # @raise [DIDError] when the DID is not PLC-based.
    def get_audit_log
      if @type == :plc
        PLCImporter.new.fetch_audit_log(self)
      else
        raise DIDError.new("Audit log not supported for did:#{@type}")
      end
    end

    # Return the web domain portion of a did:web identifier.
    #
    # @return [String, nil] web domain if type is :web.
    def web_domain
      did.gsub(/^did\:web\:/, '') if type == :web
    end

    # Fetch the account status from the PDS endpoint.
    #
    # @param request_options [Hash] request options.
    # @return [Symbol, nil] account status or nil when not found.
    # @raise [APIError] when the response is invalid.
    def account_status(request_options = {})
      doc = self.document
      return nil if doc.pds_endpoint.nil?

      pds_host = uri_origin(doc.pds_endpoint)
      url = URI("#{pds_host}/xrpc/com.atproto.sync.getRepoStatus")
      url.query = URI.encode_www_form(:did => @did)

      response = get_response(url, request_options)
      status = response.code.to_i
      is_json = (response['Content-Type'] =~ /^application\/json(;.*)?$/)

      if status == 200 && is_json
        json = JSON.parse(response.body)

        if json['active'] == true
          :active
        elsif json['active'] == false && json['status'].is_a?(String) && json['status'].length <= 100
          json['status'].to_sym
        else
          raise APIError.new(response)
        end
      elsif status == 400 && is_json && JSON.parse(response.body)['error'] == 'RepoNotFound'
        nil
      else
        raise APIError.new(response)
      end
    end

    # Check if the account is active.
    #
    # @return [Boolean] true if active.
    def account_active?
      account_status == :active
    end

    # Check if the account exists.
    #
    # @return [Boolean] true if the account exists.
    def account_exists?
      account_status != nil
    end

    # Compare to another DID or DID string.
    #
    # @param other [DID, String] value to compare.
    # @return [Boolean] true if the DID matches.
    def ==(other)
      if other.is_a?(String)
        self.did == other
      elsif other.is_a?(DID)
        self.did == other.did
      else
        false
      end
    end
  end
end
