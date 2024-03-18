require 'time'

require_relative 'service_record'
require_relative 'services'

module DIDKit
  class PLCOperation
    class FormatError < StandardError
    end

    include Services

    attr_reader :json, :did, :created_at, :type, :handles, :services

    def initialize(json)
      @json = json
      @did = json['did']
      raise FormatError, "Missing DID: #{json}" if @did.nil?
      raise FormatError, "Invalid DID: #{@did}" unless @did.is_a?(String) && @did.start_with?('did:')

      timestamp = json['createdAt']
      raise FormatError, "Missing createdAt: #{json}" if timestamp.nil?
      raise FormatError, "Invalid createdAt: #{timestamp.inspect}" unless timestamp.is_a?(String)

      @created_at = Time.parse(timestamp)

      operation = json['operation']
      raise FormatError, "Missing operation key: #{json}" if operation.nil?
      raise FormatError, "Invalid operation data: #{operation.inspect}" unless operation.is_a?(Hash)

      type = operation['type']
      raise FormatError, "Missing operation type: #{json}" if type.nil?

      @type = type.to_sym
      return unless @type == :plc_operation

      services = operation['services']
      raise FormatError, "Missing services key: #{json}" if services.nil?
      raise FormatError, "Invalid services data: #{services}" unless services.is_a?(Hash)

      @services = services.map { |k, x|
        type, endpoint = x.values_at('type', 'endpoint')

        raise FormatError, "Missing service type" unless type
        raise FormatError, "Invalid service type: #{type.inspect}" unless type.is_a?(String)
        raise FormatError, "Missing service endpoint" unless endpoint
        raise FormatError, "Invalid service endpoint: #{endpoint.inspect}" unless endpoint.is_a?(String)

        ServiceRecord.new(k, type, endpoint)
      }

      if aka = operation['alsoKnownAs']
        raise FormatError, "Invalid alsoKnownAs: #{aka.inspect}" unless aka.is_a?(Array)
        raise FormatError, "Invalid alsoKnownAs: #{aka.inspect}" unless aka.all? { |x| x.is_a?(String) }
        raise FormatError, "Invalid alsoKnownAs: #{aka.inspect}" unless aka.all? { |x| x =~ %r(\Aat://[^/]+\z) }

        @handles = aka.map { |x| x.gsub('at://', '') }
      else
        @handles = []
      end
    end
  end
end
