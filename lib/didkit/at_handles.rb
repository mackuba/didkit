module DIDKit
  # Helpers for parsing at:// handle references.
  module AtHandles
    # Raised when handle data cannot be parsed.
    class FormatError < StandardError
    end

    # Parse at:// handles from an alsoKnownAs array.
    #
    # @param aka [Array<String>] alsoKnownAs values from a DID document.
    # @return [Array<String>] handle strings without the at:// prefix.
    # @raise [FormatError] when the input is not an array of strings.
    def parse_also_known_as(aka)
      raise FormatError, "Invalid alsoKnownAs: #{aka.inspect}" unless aka.is_a?(Array)
      raise FormatError, "Invalid alsoKnownAs: #{aka.inspect}" unless aka.all? { |x| x.is_a?(String) }

      aka.select { |x| x =~ %r(\Aat://[^/]+\z) }.map { |x| x.gsub('at://', '') }
    end
  end
end
