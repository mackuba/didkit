require 'net/http'
require 'resolv'

require_relative 'did'
require_relative 'document'
require_relative 'requests'

module DIDKit
  class Resolver
    RESERVED_DOMAINS = %w(alt arpa example internal invalid local localhost onion test)

    include Requests

    attr_accessor :nameserver

    def initialize(options = {})
      @nameserver = options[:nameserver]
      @request_options = options.slice(:timeout, :max_redirects)
    end

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

    def resolve_did(did)
      did = DID.new(did) if did.is_a?(String)

      did.type == :plc ? resolve_did_plc(did) : resolve_did_web(did)
    end

    def resolve_did_plc(did)
      json = get_json("https://plc.directory/#{did}", content_type: /^application\/did\+ld\+json(;.+)?$/)
      Document.new(did, json)
    end

    def resolve_did_web(did)
      json = get_json("https://#{did.web_domain}/.well-known/did.json")
      Document.new(did, json)
    end

    def get_verified_handle(subject)
      document = subject.is_a?(Document) ? subject : resolve_did(subject)

      first_verified_handle(document.did, document.handles)
    end

    def first_verified_handle(did, handles)
      handles.detect { |h| resolve_handle(h) == did.to_s }
    end
  end
end
