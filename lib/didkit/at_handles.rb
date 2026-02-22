# frozen_string_literal: true

require_relative 'errors'

module DIDKit

  #
  # @api private
  #

  module AtHandles

    # Returns a list of ATProto handles assigned to this DID in its DID document.
    #
    # Note: the handles aren't guaranteed to be verified (validated in the other direction).
    # Use {DID#get_verified_handle} to find a handle that is correctly verified.
    #
    # @api public
    # @return [Array<String>]

    attr_reader :handles

    # Returns a list of all identifiers assigned to this DID in its DID document through the
    # `alsoKnownAs` field. This includes ATProto handles (in the format `at://example.com`) and
    # potentially other URIs like `http` URLs (e.g. for Bridgy accounts), and even (technically
    # invalid) non-URI strings. Use {#handles} to get just the ATProto handles.
    #
    # @api public
    # @return [Array<String>]

    attr_reader :also_known_as

    private

    def parse_also_known_as(aka)
      raise FormatError, "Invalid alsoKnownAs: #{aka.inspect}" unless aka.is_a?(Array)
      raise FormatError, "Invalid alsoKnownAs: #{aka.inspect}" unless aka.all? { |x| x.is_a?(String) }

      @also_known_as = aka
      @handles = aka.select { |x| x =~ %r(\Aat://[^/]+\z) }.map { |x| x.gsub('at://', '') }
    end
  end
end
