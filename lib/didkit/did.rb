require 'json'

require_relative 'errors'
require_relative 'requests'
require_relative 'resolver'

module DIDKit
  class DID
    include Requests

    def self.resolve_handle(handle)
      Resolver.new.resolve_handle(handle)
    end

    attr_reader :type, :did, :resolved_by

    def initialize(did, resolved_by = nil)
      if did =~ /^did\:(\w+)\:/
        @did = did
        @type = $1.to_sym
      else
        raise DIDError.new("Invalid DID format")
      end

      if @type != :plc && @type != :web
        raise DIDError.new("Unrecognized DID type: #{@type}")
      end

      @resolved_by = resolved_by
    end

    alias to_s did

    def document
      @document ||= get_document
    end

    def get_document
      Resolver.new.resolve_did(self)
    end

    def get_verified_handle
      Resolver.new.get_verified_handle(document)
    end

    def get_audit_log
      if @type == :plc
        PLCImporter.new.fetch_audit_log(self)
      else
        raise DIDError.new("Audit log not supported for did:#{@type}")
      end
    end

    def web_domain
      did.gsub(/^did\:web\:/, '') if type == :web
    end

    def account_status(request_options = {})
      doc = self.document
      return nil if doc.pds_endpoint.nil?

      pds_host = URI(doc.pds_endpoint).origin
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

    def account_active?
      account_status == :active
    end

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
