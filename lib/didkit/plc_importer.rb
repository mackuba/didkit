require 'json'
require 'time'
require 'uri'

require_relative 'plc_operation'
require_relative 'requests'

module DIDKit
  class PLCImporter
    PLC_SERVICE = 'plc.directory'
    MAX_PAGE = 1000

    include Requests

    attr_accessor :ignore_errors, :last_date, :error_handler

    def initialize(since: nil)
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
    end

    def plc_service
      PLC_SERVICE
    end

    def ignore_errors=(val)
      @ignore_errors = val

      if val
        @error_handler = proc { |e, j| "(ignore error)" }
      else
        @error_handler = nil
      end
    end

    def get_export(args = {})
      url = URI("https://#{plc_service}/export")
      url.query = URI.encode_www_form(args)

      data = get_data(url, content_type: 'application/jsonlines')
      data.lines.map(&:strip).reject(&:empty?).map { |x| JSON.parse(x) }
    end

    def fetch_audit_log(did)
      json = get_json("https://#{plc_service}/#{did}/log/audit", :content_type => :json)
      json.map { |j| PLCOperation.new(j) }
    end      

    def fetch_page
      request_time = Time.now

      query = @last_date ? { :after => @last_date.utc.iso8601(6) } : {}
      rows = get_export(query)

      operations = rows.filter_map { |json|
        begin
          PLCOperation.new(json)
        rescue PLCOperation::FormatError, AtHandles::FormatError, ServiceRecord::FormatError => e
          @error_handler ? @error_handler.call(e, json) : raise
          nil
        end
      }.reject { |op|
        # when you pass the most recent op's timestamp to ?after, it will be returned as the first op again,
        # so we need to use this CID list to filter it out (so pages will usually be 999 items long)

        @last_page_cids.include?(op.cid)
      }

      @last_date = operations.last&.created_at || request_time
      @last_page_cids = Set.new(operations.map(&:cid))
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
