require 'json'
require 'open-uri'
require 'time'

require_relative 'plc_operation'

module DIDKit
  class PLCImporter
    PLC_SERVICE = 'plc.directory'
    MAX_PAGE = 1000

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

      data = URI.open(url).read
      data.lines.map(&:strip).reject(&:empty?).map { |x| JSON.parse(x) }
    end

    def fetch_audit_log(did)
      response = URI.open("https://#{plc_service}/#{did}/log/audit").read
      JSON.parse(response).map { |j| PLCOperation.new(j) }
    end      

    def fetch_page
      request_time = Time.now

      query = @last_date ? { :after => @last_date.utc.iso8601(6) } : {}
      rows = get_export(query)

      operations = rows.filter_map do |json|
        begin
          PLCOperation.new(json)
        rescue PLCOperation::FormatError, AtHandles::FormatError, ServiceRecord::FormatError => e
          @error_handler ? @error_handler.call(e, json) : raise
          nil
        end
      end

      @last_date = operations.last&.created_at || request_time
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
