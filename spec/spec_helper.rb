# frozen_string_literal: true

require 'didkit'
require 'json'
require 'webmock/rspec'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  config.expect_with :rspec do |c|
    c.syntax = [:should, :expect]
  end

  config.mock_with :mocha
end

BSKY_APP_DID = 'did:plc:z72i7hdynmk6r22z27h6tvur'

WebMock.enable!

def load_did_file(name)
  File.read(File.join(__dir__, 'dids', name))
end

def load_did_json(name)
  JSON.parse(load_did_file(name))
end
