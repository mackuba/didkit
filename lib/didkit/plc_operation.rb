require 'time'

module DIDKit
  class PLCOperation
    class FormatError < StandardError
    end

    attr_reader :json, :did, :created_at, :type, :pds_endpoint, :handles

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

      if pds = services['atproto_pds']
        raise FormatError, "Invalid PDS data: #{pds.inspect}" unless pds.is_a?(Hash)
        raise FormatError, "Missing PDS type: #{pds.inspect}" unless pds['type']
        raise FormatError, "Invalid PDS type: #{pds['type']}" unless pds['type'] == 'AtprotoPersonalDataServer'

        endpoint = pds['endpoint']
        raise FormatError, "Missing PDS endpoint: #{pds.inspect}" unless endpoint
        raise FormatError, "Invalid PDS endpoint: #{endpoint}" unless endpoint.is_a?(String) && endpoint =~ %r(://)

        @pds_endpoint = endpoint
      end

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
