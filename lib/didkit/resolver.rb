# frozen_string_literal: true

require 'net/http'
require 'resolv'

require_relative 'did'
require_relative 'document'
require_relative 'requests'

module DIDKit

  #
  # A class which manages resolving of handles to DIDs and DIDs to DID documents.
  #

  class Resolver
    # These TLDs are not allowed in ATProto handles, so the resolver returns nil for them
    # without trying to look them up.
    RESERVED_DOMAINS = %w(alt arpa example internal invalid local localhost onion test)

    include Requests

    # @return [String, Array<String>] custom DNS nameserver(s) to use for DNS TXT lookups
    attr_accessor :nameserver

    # @param options [Hash] resolver options
    # @option options [String, Array<String>] :nameserver custom DNS nameserver(s) to use (IP or an array of IPs)
    # @option options [Integer] :timeout request timeout in seconds (default: 15)
    # @option options [Integer] :max_redirects maximum number of redirects to follow (default: 5)

    def initialize(options = {})
      @nameserver = options[:nameserver]
      @request_options = options.slice(:timeout, :max_redirects)
    end

    # Resolve a handle into a DID. Looks up the given ATProto domain handle using the DNS TXT method
    # and the HTTP .well-known method and returns a DID if one is assigned using either of the methods.
    #
    # If a DID string or a {DID} object is passed, it simply returns that DID, so you can use this
    # method to pass it an input string from the user which can be a DID or handle, without having to
    # check which one it is.
    #
    # @param handle [String, DID] a domain handle (may start with an `@`) or a DID string
    # @return [DID, nil] resolved DID if found, nil otherwise

    def resolve_handle(handle)
      if handle.is_a?(DID) || handle =~ DID::GENERIC_REGEXP
        return DID.new(handle)
      end

      domain = handle.gsub(/^@/, '')

      return nil if RESERVED_DOMAINS.include?(domain.split('.').last)

      if dns_did = resolve_handle_by_dns(domain)
        DID.new(dns_did, :dns)
      elsif http_did = resolve_handle_by_well_known(domain)
        DID.new(http_did, :http)
      else
        nil
      end
    end

    # Tries to resolve a handle into DID using the DNS TXT method.
    #
    # Checks the DNS records for a given domain for an entry `_atproto.#{domain}` whose value is
    # a correct DID string.
    #
    # @param domain [String] a domain handle to look up
    # @return [String, nil] resolved DID if found, nil otherwise

    def resolve_handle_by_dns(domain)
      dns_records = Resolv::DNS.open(resolv_options) do |d|
        d.getresources("_atproto.#{domain}", Resolv::DNS::Resource::IN::TXT)
      end

      if record = dns_records.first
        if string = record.strings.first
          return parse_did_from_dns(string)
        end
      end

      nil
    end

    # Tries to resolve a handle into DID using the HTTP .well-known method.
    #
    # Checks the `/.well-known/atproto-did` endpoint on the given domain to see if it returns
    # a text file that contains a correct DID string.
    #
    # @param domain [String] a domain handle to look up
    # @return [String, nil] resolved DID if found, nil otherwise

    def resolve_handle_by_well_known(domain)
      url = "https://#{domain}/.well-known/atproto-did"
      response = get_response(url, @request_options)

      if response.is_a?(Net::HTTPSuccess) && (text = response.body)
        return parse_did_from_well_known(text)
      end

      nil
    rescue StandardError => e
      nil
    end

    # Resolve a DID to a DID document.
    #
    # Looks up the DID document with the DID's identity details from an appropriate source, i.e. either
    # [plc.directory](https://plc.directory) for did:plc DIDs, or the did:web's domain for did:web DIDs.
    #
    # @param did [String, DID] DID string or object
    # @return [Document] resolved DID document
    # @raise [APIError] if an incorrect response is returned

    def resolve_did(did)
      did = DID.new(did) if did.is_a?(String)

      did.type == :plc ? resolve_did_plc(did) : resolve_did_web(did)
    end

    # Returns the first verified handle assigned to the given DID.
    #
    # Looks up the domain handles assigned to the DID in the DID document, checks if they are
    # verified (i.e. assigned correctly to this DID using DNS TXT or .well-known) and returns
    # the first handle that validates correctly, or nil if none matches.
    #
    # @param subject [String, DID, Document] a DID or its DID document
    # @return [String, nil] verified handle domain, if found

    def get_verified_handle(subject)
      document = subject.is_a?(Document) ? subject : resolve_did(subject)

      first_verified_handle(document.did, document.handles)
    end

    # Returns the first handle from the list that resolves back to the given DID.
    #
    # @param did [DID, String] DID to verify the handles against
    # @param handles [Array<String>] handles to check
    # @return [String, nil] a verified handle, if found

    def first_verified_handle(did, handles)
      handles.detect { |h| resolve_handle(h) == did.to_s }
    end


    private

    def resolv_options
      options = Resolv::DNS::Config.default_config_hash.dup
      options[:nameserver] = nameserver if nameserver
      options
    end

    def parse_did_from_dns(txt)
      txt =~ /\Adid\=(did\:\w+\:.*)\z/ ? $1 : nil
    end

    def parse_did_from_well_known(text)
      text = text.strip
      text.lines.length == 1 && text =~ DID::GENERIC_REGEXP ? text : nil
    end

    def resolve_did_plc(did)
      json = get_json("https://plc.directory/#{did}", content_type: /^application\/did\+ld\+json(;.+)?$/)
      Document.new(did, json)
    end

    def resolve_did_web(did)
      json = get_json("https://#{did.web_domain}/.well-known/did.json")
      Document.new(did, json)
    end
  end
end
