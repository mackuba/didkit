require 'json'
require 'open-uri'
require 'net/http'
require 'resolv'

require_relative 'did'
require_relative 'document'

module DIDKit
  class Resolver
    RESERVED_DOMAINS = %w(alt arpa example internal invalid local localhost onion test)

    def resolve_handle(handle)
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

    def resolve_handle_by_well_known(domain)
      url = URI("https://#{domain}/.well-known/atproto-did")

      response = Net::HTTP.start(url.host, url.port, use_ssl: true, open_timeout: 10, read_timeout: 10) do |http|
        request = Net::HTTP::Get.new(url)
        http.request(request)
      end

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

    def resolve_did(did)
      did = DID.new(did) if did.is_a?(String)

      did.type == :plc ? resolve_did_plc(did) : resolve_did_web(did)
    end

    def resolve_did_plc(did)
      url = "https://plc.directory/#{did}"
      json = JSON.parse(URI.open(url).read)
      Document.new(did, json)
    end

    def resolve_did_web(did)
      url = "https://#{did.web_domain}/.well-known/did.json"
      json = JSON.parse(URI.open(url).read)
      Document.new(did, json)
    end

    def get_validated_handle(did_or_doc)
      document = did_or_doc.is_a?(Document) ? did_or_doc : resolve_did(did_or_doc)

      document.handles.detect { |h| resolve_handle(h) == document.did }
    end
  end
end
