# frozen_string_literal: true

require 'json'
require 'set'
require 'time'
require 'uri'

require_relative 'constants'
require_relative 'errors'
require_relative 'plc_operation'
require_relative 'requests'

#
# NOTE: this class is pending a rewrite to handle updated plc.directory APIs.
# Things will change here in v. 0.6.
#

module DIDKit
  class PLCImporter
    MAX_PAGE = 1000

    include Requests

    attr_accessor :last_date

    def initialize(since: nil, service: nil)
      if since.to_s == 'beginning'
        @last_date = nil
      elsif since.is_a?(String)
        @last_date = Time.parse(since)
      elsif since
        @last_date = since
      else
        @last_date = Time.now
        @eof = true
      end

      @last_page_cids = []

      @plc_service = service || DIDKit::DEFAULT_PLC_DIRECTORY
      @plc_service = "https://#{@plc_service}" unless @plc_service.include?('://')
    end

    def get_export(args = {})
      url = URI("#{@plc_service}/export")
      url.query = URI.encode_www_form(args)

      data = get_data(url, content_type: 'application/jsonlines')
      data.lines.map(&:strip).reject(&:empty?).map { |x| JSON.parse(x) }
    end

    def fetch_audit_log(did)
      json = get_json("#{@plc_service}/#{did}/log/audit", :content_type => :json)
      json.map { |j| PLCOperation.new(j) }
    end

    def fetch_page
      query = @last_date ? { :after => @last_date.utc.iso8601(6) } : {}
      rows = get_export(query)

      operations = rows.map { |json|
        PLCOperation.new(json)
      }.reject { |op|
        # when you pass the most recent op's timestamp to ?after, it will be returned as the first op again,
        # so we need to use this CID list to filter it out (so pages will usually be 999 items long)

        @last_page_cids.include?(op.cid)
      }

      unless operations.empty?
        @last_date = operations.last.created_at
        @last_page_cids = Set.new(operations.map(&:cid))
      end

      @eof = (rows.length < MAX_PAGE)

      operations
    end

    def fetch(&block)
      loop do
        operations = fetch_page
        block.call(operations)
        break if eof?
      end
    end

    def eof?
      !!@eof
    end
  end
end
