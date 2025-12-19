# frozen_string_literal: true

require 'simplecov'

SimpleCov.start do
  enable_coverage :branch
  add_filter "/spec/"
end

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

module SimpleCov
  module Formatter
    class HTMLFormatter
      def format(result)
        # silence the stdout summary, just save the html files
        unless @inline_assets
          Dir[File.join(@public_assets_dir, "*")].each do |path|
            FileUtils.cp_r(path, asset_output_path, remove_destination: true)
          end
        end

        File.open(File.join(output_path, "index.html"), "wb") do |file|
          file.puts template("layout").result(binding)
        end
      end
    end
  end
end

BSKY_APP_DID = 'did:plc:z72i7hdynmk6r22z27h6tvur'

WebMock.enable!

def load_did_file(name)
  File.read(File.join(__dir__, 'dids', name))
end

def load_did_json(name)
  JSON.parse(load_did_file(name))
end
