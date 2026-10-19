require_relative 'did'

unless defined?(::DID)
  DID = DIDKit::DID
end
