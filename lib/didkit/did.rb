require 'json'
require 'net/http'
require 'open-uri'
require 'resolv'

require_relative 'document'
require_relative 'errors'

module DIDKit
  class DID
    def self.resolve_handle(handle)
      domain = handle.gsub(/^@/, '')

      if dns_did = resolve_handle_by_dns(domain)
        DID.new(dns_did)
      elsif http_did = resolve_handle_by_well_known(domain)
        DID.new(http_did)
      else
        nil
      end
    end

    def self.resolve_handle_by_dns(domain)
      dns_records = Resolv::DNS.open { |d| d.getresources("_atproto.#{domain}", Resolv::DNS::Resource::IN::TXT) }

      if record = dns_records.first
        if string = record.strings.first
          if string =~ /^did\=(did\:\w+\:.*)$/
            return $1
          end
        end
      end

      nil
    end

    def self.resolve_handle_by_well_known(domain)
      url = URI("https://#{domain}/.well-known/atproto-did")
      response = Net::HTTP.get_response(url)

      if response.is_a?(Net::HTTPSuccess)
        if text = response.body
          if text.lines.length == 1 && text.start_with?('did:')
            return text
          end
        end
      end

      nil
    rescue StandardError => e
      nil
    end

    attr_reader :type

    def initialize(did)
      if did =~ /^did\:(\w+)\:/
        @did = did
        @type = $1.to_sym
      else
        raise DIDError.new("Invalid DID format")
      end

      if @type != :plc && @type != :web
        raise DIDError.new("Unrecognized DID type: #{@type}")
      end
    end

    def to_s
      @did
    end

    def get_document
      type == :plc ? resolve_did_plc : resolve_did_web
    end

    def resolve_did_plc
      url = "https://plc.directory/#{did}"
      json = JSON.parse(URI.open(url).read)
      Document.new(self, json)
    end

    def resolve_did_web
      host = did.gsub(/^did\:web\:/, '')
      url = "https://#{host}/.well-known/did.json"
      json = JSON.parse(URI.open(url).read)
      Document.new(self, json)
    end
  end
end
