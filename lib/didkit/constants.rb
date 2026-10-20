# frozen_string_literal: true

module DIDKit
  # URL of the standard PLC directory service.
  DEFAULT_PLC_DIRECTORY = 'https://plc.directory'

  DOMAIN_SEGMENT =      /[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?/
  LAST_DOMAIN_SEGMENT =    /[a-zA-Z]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?/
  private_constant :DOMAIN_SEGMENT, :LAST_DOMAIN_SEGMENT

  # Pattern that matches any valid ATProto handle (without @)
  HANDLE_REGEXP = /\A(#{DOMAIN_SEGMENT}\.)+#{LAST_DOMAIN_SEGMENT}\z/

  # Pattern that matches any valid did:plc DID
  DID_PLC_REGEXP = /\Adid\:plc\:[abcdefghijklmnopqrstuvwxyz234567]{24}\z/

  # Pattern that matches a percent-decoded did:web DID
  DID_WEB_REGEXP = /\Adid\:web\:((#{DOMAIN_SEGMENT}\.)+#{LAST_DOMAIN_SEGMENT}|localhost(:[1-9][0-9]{0,4})?)\z/

  # Pattern that matches any valid DID (including methods unsupported in ATProto)
  GENERIC_DID_REGEXP = /\Adid:[a-z]+:[a-zA-Z0-9_\.\:\%\-]*[a-zA-Z0-9_\.\-]\z/

  # Maximum allowed DID length in ATProto
  MAX_DID_LENGTH = 2048

  # Maximum allowed handle length in ATProto
  MAX_HANDLE_LENGTH = 253

  # TLDs that are not allowed in ATProto handles
  RESERVED_DOMAINS = %w(alt arpa example internal invalid local localhost onion test)
end
