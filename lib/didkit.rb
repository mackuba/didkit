# frozen_string_literal: true

require_relative "didkit/did"
require_relative "didkit/document"
require_relative "didkit/plc_importer"
require_relative "didkit/plc_operation"
require_relative "didkit/resolver"
require_relative "didkit/version"

# Root namespace for DIDKit services and models.
module DIDKit
end

DID = DIDKit::DID
