# frozen_string_literal: true

require 'base58'
require 'openssl'
require_relative 'errors'

module DIDKit

  #
  # A public signing key of an ATProto account, decoded from its DID document or PLC operation.
  #
  # Both `k256` (`secp256k1`) and `p256` (`secp256r1`, `prime256v1`) keys are supported. Keys from
  # legacy DID documents (before August 2023) without a `did:key:` prefix are intentionally *not* supported.
  #
  # Related documentation:
  # - [ATProto: Cryptography](https://atproto.com/specs/cryptography)
  # - [02, 03 or 04? So What Are Compressed and Uncompressed Public Keys?](https://medium.com/asecuritysite-when-bob-met-alice/02-03-or-04-so-what-are-compressed-and-uncompressed-public-keys-6abcb57efeb6)
  # - [multicodec](https://github.com/multiformats/multicodec)
  #

  class PublicKey

    # Multicodec varint prefix for a compressed `k256` public key.
    K256_PREFIX = "\xE7\x01".b.freeze

    # Multicodec varint prefix for a compressed `p256` public key.
    P256_PREFIX = "\x80\x24".b.freeze

    # OpenSSL group name for the K-256 curve.
    K256_GROUP_NAME = 'secp256k1'

    # OpenSSL group name for the P-256 curve.
    P256_GROUP_NAME = 'prime256v1'

    # @return [String] a 33-byte binary string containing the raw compressed public key
    attr_reader :compressed_key

    # @return [String] the original multikey value, Base58-encoded with a `z` multibase prefix
    attr_reader :multibase


    # Decodes and validates an ATProto account public key.
    #
    # @param string [String] key in the multikey string form, without the `did:key:` prefix
    # @raise [ArgumentError] when the argument is not a string
    # @raise [KeyError] when the key is invalid, incorrectly encoded, or has unsupported type

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

    # Returns a short name of the key's elliptic curve.
    # @return [Symbol] `:k256` or `:p256`

    def type
      @key_type
    end

    # Returns the OpenSSL elliptic curve group representing the given key's type.
    # @return [OpenSSL::PKey::EC::Group] the `secp256k1` or `prime256v1` group

    def ec_group
      @ec_group ||= OpenSSL::PKey::EC::Group.new(@key_type == :k256 ? K256_GROUP_NAME : P256_GROUP_NAME)
    end

    # Returns the OpenSSL object representing the key's point on the elliptic curve.
    #
    # @return [OpenSSL::PKey::EC::Point] elliptic curve point for the key

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
