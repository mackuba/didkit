require 'time'

module DIDKit
  class PLCOperation
    class FormatError < StandardError
    end

    attr_reader :did, :created_at, :type, :pds_endpoint, :handles

    def initialize(json)
      @did = json['did']
      raise FormatError, "Missing DID" if @did.nil?
      raise FormatError, "Invalid DID" unless @did.is_a?(String) && @did.start_with?('did:')

      timestamp = json['createdAt']
      raise FormatError, "Missing createdAt" if timestamp.nil?
      raise FormatError, "Invalid createdAt" unless timestamp.is_a?(String)

      @created_at = Time.parse(timestamp)

      operation = json['operation']
      raise FormatError, "Missing operation key" if operation.nil?
      raise FormatError, "Invalid operation data" unless operation.is_a?(Hash)

      type = operation['type']
      raise FormatError, "Missing type" if type.nil?

      @type = type.to_sym
      return unless @type == :plc_operation

      services = operation['services']
      raise FormatError, "Missing services key" if services.nil?
      raise FormatError, "Invalid services data" unless services.is_a?(Hash)

      if pds = services['atproto_pds']
        raise FormatError, "Invalid PDS data" unless pds.is_a?(Hash)
        raise FormatError, "Missing PDS type" unless pds['type']
        raise FormatError, "Invalid PDS type" unless pds['type'] == 'AtprotoPersonalDataServer'
        raise FormatError, "Missing PDS endpoint" unless pds['endpoint']
        raise FormatError, "Invalid PDS endpoint" unless pds['endpoint'].is_a?(String) && pds['endpoint'] =~ %r(://)

        @pds_endpoint = pds['endpoint']
      end

      if aka = operation['alsoKnownAs']
        raise FormatError, "Invalid alsoKnownAs" unless aka.is_a?(Array)
        raise FormatError, "Invalid alsoKnownAs" unless aka.all? { |x| x.is_a?(String) }
        raise FormatError, "Invalid alsoKnownAs" unless aka.all? { |x| x =~ %r(\Aat://[^/]+\z) }

        @handles = aka.map { |x| x.gsub('at://', '') }
      else
        @handles = []
      end
    end
  end
end
