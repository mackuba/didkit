# frozen_string_literal: true

require 'base58'
require 'openssl'
require_relative 'errors'

module DIDKit
  class PublicKey
    K256_PREFIX = "\xE7\x01".b.freeze
    P256_PREFIX = "\x80\x24".b.freeze

    K256_GROUP_NAME = 'secp256k1'
    P256_GROUP_NAME = 'prime256v1'

    attr_reader :compressed_key, :multibase

    def initialize(string)
      raise ArgumentError, "Expected a string argument" unless string.is_a?(String)
      raise KeyError, "Unsupported key encoding: #{string.inspect}" unless string.start_with?('z')
      @multibase = string

      begin
        key_decoded = Base58.base58_to_binary(string[1..-1], :bitcoin)
      rescue ArgumentError
        raise KeyError, "Invalid Base58 encoding in key data"
      end

      prefix = key_decoded.byteslice(0, 2)

      case prefix
      when K256_PREFIX
        @key_type = :k256
      when P256_PREFIX
        @key_type = :p256
      else
        raise KeyError, "Unsupported key type: #{string.inspect}"
      end

      raise KeyError, "Invalid key length (#{key_decoded.bytesize})" unless key_decoded.bytesize == 35

      @compressed_key = key_decoded.byteslice(2, 33)

      validate_ec_point
    end

    def type
      @key_type
    end

    def ec_group
      @ec_group ||= OpenSSL::PKey::EC::Group.new(@key_type == :k256 ? K256_GROUP_NAME : P256_GROUP_NAME)
    end

    def ec_point
      @ec_point ||= OpenSSL::PKey::EC::Point.new(ec_group, @compressed_key)
    end

    private

    def validate_ec_point
      if !ec_point.on_curve?
        raise KeyError, "Invalid key data: #{@multibase.inspect}"
      end
    rescue OpenSSL::OpenSSLError
      raise KeyError, "Invalid key data: #{@multibase.inspect}"
    end
  end
end
