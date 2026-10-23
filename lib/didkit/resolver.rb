# frozen_string_literal: true

require 'ipaddr'
require 'net/http'
require 'resolv'
require 'uri'

require_relative 'constants'
require_relative 'did'
require_relative 'document'
require_relative 'requests'

module DIDKit

  class << self
    # Default shared resolver used when calling {DID}/{Document} methods directly.
    # @return [DIDKit::Resolver]
    def default_resolver
      @default_resolver ||= Resolver.new
    end

    attr_writer :default_resolver
  end


  #
  # A class which manages resolving of handles to DIDs and DIDs to DID documents.
  #

  class Resolver
    include Requests

    # @return [String, Array<String>, nil] custom DNS nameserver(s) to use for DNS TXT lookups
    attr_reader :nameserver

    # @param options [Hash] resolver options
    # @option options [String, Array<String>] :nameserver custom DNS nameserver(s) to use (IP or an array of IPs)
    # @option options [String] :plc_directory URL or host[:port] of an alternate PLC directory,
    #   without a path; defaults to HTTPS (HTTP allowed for localhost/loopback IPs only)
    # @option options [Integer] :timeout request timeout in seconds (default: 15)
    # @option options [Integer] :max_redirects maximum number of redirects to follow (default: 5)
    # @raise [ArgumentError] if the PLC directory address is invalid
    #
    def initialize(options = {})
      @nameserver = options[:nameserver]
      @plc_service = options.key?(:plc_directory) ? parse_plc_service(options[:plc_directory]) : DEFAULT_PLC_DIRECTORY
      @request_options = options.slice(:timeout, :max_redirects).freeze
    end

    # Resolve a handle into a DID. Looks up the given ATProto domain handle using the DNS TXT method
    # and the HTTP .well-known method and returns a DID if one is assigned using either of the methods.
    #
    # If a DID string or a {DID} object is passed, it simply returns that DID, so you can use this
    # method to pass it an input string from the user which can be a DID or handle, without having to
    # check which one it is.
    #
    # @param handle [String, DID] a domain handle (may start with an `@`) or a DID string
    # @param verify [Boolean] require the handle to be assigned to the DID in the DID document (default: true)
    # @return [DID, nil] resolved DID if found, nil otherwise
    # @raise [APIError] if verification is enabled and the DID document request is unsuccessful
    # @raise [FormatError] if verification is enabled and the DID document has invalid data

    def resolve_handle(handle, verify: true)
      if !(handle.is_a?(DID) || handle.is_a?(String))
        raise ArgumentError, "handle argument should be a String or a DID object"
      end

      if handle.is_a?(DID) || handle =~ DIDKit::GENERIC_DID_REGEXP
        return DID.new(handle)
      end

      domain = handle.gsub(/^@/, '').downcase(:ascii)
      return nil unless valid_handle_identifier?(domain)

      if dns_did = resolve_handle_by_dns(domain)
        referenced_did = DID.new(dns_did, :dns)
      elsif http_did = resolve_handle_by_well_known(domain)
        referenced_did = DID.new(http_did, :http)
      else
        return nil
      end

      if verify
        document = self.resolve_did(referenced_did)
        return nil unless document.handles.first&.downcase == domain
      end

      referenced_did
    end

    # Tries to resolve a handle into DID using the DNS TXT method.
    #
    # Checks the DNS records for a given domain for an entry `_atproto.#{domain}` whose value is
    # a correct DID string. Records are rejected if there exists more than one valid entry and they
    # are referencing two or more different DIDs.
    #
    # @param domain [String] a domain handle to look up
    # @return [String, nil] resolved DID if one valid record is found, nil otherwise

    def resolve_handle_by_dns(domain)
      dns_records = Resolv::DNS.open(resolv_options) do |d|
        d.getresources("_atproto.#{domain}", Resolv::DNS::Resource::IN::TXT)
      end

      dids = dns_records.map { |record| parse_did_from_dns(record.data) }.compact.uniq

      dids.length == 1 ? dids.first : nil
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
    rescue StandardError
      nil
    end

    # Resolve a DID to a DID document.
    #
    # Looks up the DID document with the DID's identity details from an appropriate source, i.e. either
    # [plc.directory](https://plc.directory) or its mirror for did:plc DIDs, or the did:web's domain
    # for did:web DIDs.
    #
    # @param did [String, DID] DID string or object
    # @return [Document] resolved DID document
    # @raise [APIError] if an incorrect response is returned

    def resolve_did(did)
      did = DID.new(did) if did.is_a?(String)

      did.type == :plc ? resolve_did_plc(did) : resolve_did_web(did)
    end

    # Returns the current primary handle assigned to the given DID, if it verifies correctly.
    #
    # Looks up the first syntactically valid handle in the DID document and checks if it is assigned
    # correctly to this DID using DNS TXT or .well-known. Any later handles are ignored, even if the
    # first handle fails verification. Returns nil if the primary handle cannot be verified.
    #
    # @param subject [String, DID, Document] a DID or its DID document
    # @return [String, nil] verified handle domain, if found

    def get_verified_handle(subject)
      document = subject.is_a?(Document) ? subject : resolve_did(subject)

      primary_handle = document.handles.first

      return nil if primary_handle.nil?
      return nil unless resolve_handle(primary_handle, verify: false) == document.did.to_s

      primary_handle
    end


    private

    def valid_handle_identifier?(handle)
      return false unless handle =~ DIDKit::HANDLE_REGEXP && handle.length <= DIDKit::MAX_HANDLE_LENGTH
      return false if DIDKit::RESERVED_DOMAINS.include?(handle.split('.').last)

      true
    end

    def resolv_options
      options = Resolv::DNS::Config.default_config_hash.dup
      options[:nameserver] = nameserver if nameserver
      options
    end

    def parse_plc_service(url)
      raise ArgumentError, 'PLC directory URL must be a string' unless url.is_a?(String)

      url = "https://#{url}" unless url.include?('://')
      uri = URI.parse(url.chomp('/'))

      unless uri.is_a?(URI::HTTP) && uri.host && !uri.host.empty? && uri.path.empty?
        raise ArgumentError, 'PLC directory must be a hostname or a HTTP(S) URL without a path'
      end

      unless !uri.userinfo && !uri.query && !uri.fragment
        raise ArgumentError, 'PLC directory URL must not include user credentials, query, or fragment part'
      end

      if uri.scheme == 'http' && !loopback_host?(uri.hostname)
        raise ArgumentError, 'http:// URLs are allowed only with localhost or a loopback IP'
      end

      uri.to_s
    rescue URI::InvalidURIError
      raise ArgumentError, 'Invalid PLC directory URL'
    end

    def loopback_host?(host)
      host.downcase(:ascii) == 'localhost' || IPAddr.new(host).loopback?
    rescue IPAddr::InvalidAddressError
      false
    end

    def valid_did?(did)
      DID.new(did)
      true
    rescue DIDError
      false
    end

    def parse_did_from_dns(txt)
      return nil unless txt.start_with?('did=')

      did = txt.delete_prefix('did=')

      valid_did?(did) ? did : nil
    end

    def parse_did_from_well_known(text)
      text = text.strip
      text.lines.length == 1 && valid_did?(text) ? text : nil
    end

    def resolve_did_plc(did)
      options = @request_options.merge(content_type: /^application\/did(\+ld)?\+json(;.+)?$/)
      json = get_json("#{@plc_service}/#{did}", options)
      Document.new(did, json)
    end

    def resolve_did_web(did)
      json = get_json("#{did.did_web_host}/.well-known/did.json", @request_options)
      Document.new(did, json)
    end
  end
end
