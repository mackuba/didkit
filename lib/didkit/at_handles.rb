module DIDKit
  module AtHandles
    class FormatError < StandardError
    end

    def parse_also_known_as(aka)
      raise FormatError, "Invalid alsoKnownAs: #{aka.inspect}" unless aka.is_a?(Array)
      raise FormatError, "Invalid alsoKnownAs: #{aka.inspect}" unless aka.all? { |x| x.is_a?(String) }

      aka.select { |x| x =~ %r(\Aat://[^/]+\z) }.map { |x| x.gsub('at://', '') }
    end
  end
end
