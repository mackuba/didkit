require 'net/http'
require 'resolv'

require_relative 'did'
require_relative 'document'
require_relative 'requests'

module DIDKit
  # Resolves handles and DIDs using DNS and well-known endpoints.
  class Resolver
    RESERVED_DOMAINS = %w(alt arpa example internal invalid local localhost onion test)

    include Requests

    attr_accessor :nameserver

    # Initialize a resolver with optional request and DNS settings.
    #
    # @param options [Hash] resolver options.
    # @option options [String] :nameserver custom DNS nameserver.
    # @option options [Integer] :timeout request timeout in seconds.
    # @option options [Integer] :max_redirects maximum redirects to follow.
    def initialize(options = {})
      @nameserver = options[:nameserver]
      @request_options = options.slice(:timeout, :max_redirects)
    end

    # Resolve a handle to a DID.
    #
    # @param handle [String, DID] handle string or DID.
    # @return [DID, nil] resolved DID if found.
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

    # Resolve a handle using DNS TXT records.
    #
    # @param domain [String] domain to resolve.
    # @return [String, nil] DID string if found.
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

    # Resolve a handle using the well-known atproto DID endpoint.
    #
    # @param domain [String] domain to resolve.
    # @return [String, nil] DID string if found.
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

    # Build DNS resolver options.
    #
    # @return [Hash] Resolv options hash.
    def resolv_options
      options = Resolv::DNS::Config.default_config_hash.dup
      options[:nameserver] = nameserver if nameserver
      options
    end

    # Parse DID from DNS TXT record.
    #
    # @param txt [String] TXT record string.
    # @return [String, nil] DID string if present.
    def parse_did_from_dns(txt)
      txt =~ /\Adid\=(did\:\w+\:.*)\z/ ? $1 : nil
    end

    # Parse DID from well-known response body.
    #
    # @param text [String] response body text.
    # @return [String, nil] DID string if present.
    def parse_did_from_well_known(text)
      text = text.strip
      text.lines.length == 1 && text =~ DID::GENERIC_REGEXP ? text : nil
    end

    # Resolve a DID to a DID document.
    #
    # @param did [String, DID] DID string or object.
    # @return [Document] resolved DID document.
    def resolve_did(did)
      did = DID.new(did) if did.is_a?(String)

      did.type == :plc ? resolve_did_plc(did) : resolve_did_web(did)
    end

    # Resolve a PLC DID to a document via plc.directory.
    #
    # @param did [DID] PLC DID.
    # @return [Document] resolved DID document.
    def resolve_did_plc(did)
      json = get_json("https://plc.directory/#{did}", content_type: /^application\/did\+ld\+json(;.+)?$/)
      Document.new(did, json)
    end

    # Resolve a web DID to a document via did.json.
    #
    # @param did [DID] web DID.
    # @return [Document] resolved DID document.
    def resolve_did_web(did)
      json = get_json("https://#{did.web_domain}/.well-known/did.json")
      Document.new(did, json)
    end

    # Get the first verified handle for a DID or document.
    #
    # @param subject [DID, Document] DID or document.
    # @return [String, nil] verified handle if found.
    def get_verified_handle(subject)
      document = subject.is_a?(Document) ? subject : resolve_did(subject)

      first_verified_handle(document.did, document.handles)
    end

    # Return the first handle that resolves to the given DID.
    #
    # @param did [DID] DID to verify against.
    # @param handles [Array<String>] handle candidates.
    # @return [String, nil] verified handle if found.
    def first_verified_handle(did, handles)
      handles.detect { |h| resolve_handle(h) == did.to_s }
    end
  end
end
