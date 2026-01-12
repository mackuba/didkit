require 'json'
require 'uri'

require_relative 'errors'
require_relative 'requests'
require_relative 'resolver'

module DIDKit

  #
  # Represents a DID identifier (account on the ATProto network). This class serves as an entry
  # point to various lookup helpers. For convenience it can also be accessed as just `DID` without
  # the `DIDKit::` prefix.
  #
  # @example Resolving a handle
  #   did = DID.resolve_handle('bsky.app')
  #

  class DID
    GENERIC_REGEXP = /\Adid\:\w+\:.+\z/

    include Requests

    # Resolve a handle into a DID. Looks up the given ATProto domain handle using the DNS TXT method
    # and the HTTP .well-known method and returns a DID if one is assigned using either of the methods.
    #
    # If a DID string or a {DID} object is passed, it simply returns that DID, so you can use this
    # method to pass it an input string from the user which can be a DID or handle, without having to
    # check which one it is.
    #
    # @param handle [String, DID] a domain handle (may start with an `@`) or a DID string
    # @return [DID, nil] resolved DID if found, nil otherwise

    def self.resolve_handle(handle)
      Resolver.new.resolve_handle(handle)
    end

    # @return [Symbol] DID type (`:plc` or `:web`)
    attr_reader :type

    # @return [String] DID identifier string
    attr_reader :did

    # @return [Symbol, nil] `:dns` or `:http` if the DID was looked up using one of those methods
    attr_reader :resolved_by

    alias to_s did


    # Create a DID object from a DID string.
    #
    # @param did [String, DID] DID string or another DID object
    # @param resolved_by [Symbol, nil] optionally, how the DID was looked up (`:dns` or `:http`)
    # @raise [DIDError] when the DID format or type is invalid

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

    # Returns or looks up the DID document with the DID's identity details from an appropriate source.
    # This method caches the document in a local variable if it's called again.
    #
    # @return [Document] resolved DID document

    def document
      @document ||= get_document
    end

    # Looks up the DID document with the DID's identity details from an appropriate source.
    # @return [Document] resolved DID document

    def get_document
      Resolver.new.resolve_did(self)
    end

    # Returns the first verified handle assigned to this DID.
    #
    # Looks up the domain handles assigned to this DID in its DID document, checks if they are
    # verified (i.e. assigned correctly to this DID using DNS TXT or .well-known) and returns
    # the first handle that validates correctly, or nil if none matches.
    #
    # @return [String, nil] verified handle domain, if found

    def get_verified_handle
      Resolver.new.get_verified_handle(document)
    end

    # Fetches the PLC audit log (list of all previous operations) for a did:plc DID.
    #
    # @return [Array<PLCOperation>] list of PLC operations in the audit log
    # @raise [DIDError] when the DID is not a did:plc

    def get_audit_log
      if @type == :plc
        PLCImporter.new.fetch_audit_log(self)
      else
        raise DIDError.new("Audit log not supported for did:#{@type}")
      end
    end

    # Returns the domain portion of a did:web identifier.
    #
    # @return [String, nil] DID domain if the DID is a did:web, nil for did:plc

    def web_domain
      did.gsub(/^did\:web\:/, '') if type == :web
    end

    # Checks the status of the account/repo on its own PDS using the `getRepoStatus` endpoint.
    #
    # @param request_options [Hash] request options to override
    # @option request_options [Integer] :timeout request timeout (default: 15)
    # @option request_options [Integer] :max_redirects maximum number of redirects to follow (default: 5)
    #
    # @return [Symbol, nil] `:active`, or returned inactive status, or `nil` if account is not found
    # @raise [APIError] when the response is invalid

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

    # Checks if the account is seen as active on its own PDS, using the `getRepoStatus` endpoint.
    # This is a helper which calls the {#account_status} method and checks if the status is `:active`.
    #
    # @return [Boolean] true if the returned status is active
    # @raise [APIError] when the response is invalid

    def account_active?
      account_status == :active
    end

    # Checks if the account exists its own PDS, using the `getRepoStatus` endpoint.
    # This is a helper which calls the {#account_status} method and checks if the repo is found at all.
    #
    # @return [Boolean] true if the returned status is valid, false if repo is not found
    # @raise [APIError] when the response is invalid

    def account_exists?
      account_status != nil
    end

    # Compares the DID to another DID object or string.
    #
    # @param other [DID, String] other DID to compare with
    # @return [Boolean] true if it's the same DID

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
