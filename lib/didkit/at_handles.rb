require_relative 'errors'

module DIDKit

  #
  # @private
  #

  module AtHandles

    private

    def parse_also_known_as(aka)
      raise FormatError, "Invalid alsoKnownAs: #{aka.inspect}" unless aka.is_a?(Array)
      raise FormatError, "Invalid alsoKnownAs: #{aka.inspect}" unless aka.all? { |x| x.is_a?(String) }

      aka.select { |x| x =~ %r(\Aat://[^/]+\z) }.map { |x| x.gsub('at://', '') }
    end
  end
end
