# frozen_string_literal: true

require 'open3'
require 'rbconfig'

describe 'the global DID alias' do
  let(:lib_path) { File.expand_path('../lib', __dir__) }
  let(:did_string) { 'did:plc:yk4dd2qkboz2yv6tpubpc6co' }

  context "when requiring 'didkit/did' directly" do
    it 'should expose only DIDKit::DID' do
      code = <<~RUBY
        require 'didkit/did'
        puts DIDKit::DID.new(#{did_string.inspect}).to_s
        puts Object.const_defined?(:DID, false)
      RUBY

      stdout, stderr, status = Open3.capture3(RbConfig.ruby, '-I', lib_path, '-e', code)

      stderr.should == ''
      status.success?.should == true
      stdout.should == "#{did_string}\nfalse\n"
    end
  end

  ['didkit', 'didkit/global_did'].each do |entry_point|
    context "when requiring '#{entry_point}'" do
      it 'should expose DIDKit::DID as DID when the constant is not defined yet' do
        code = <<~RUBY
          require #{entry_point.inspect}
          puts ::DID.equal?(DIDKit::DID)
          puts ::DID.new(#{did_string.inspect}).to_s
        RUBY

        stdout, stderr, status = Open3.capture3(RbConfig.ruby, '-I', lib_path, '-e', code)

        stderr.should == ''
        status.success?.should == true
        stdout.should == "true\n#{did_string}\n"
      end

      it 'should preserve an existing DID constant if something else has already defined it' do
        code = <<~RUBY
          class DID; end
          original_did = ::DID

          require #{entry_point.inspect}
          puts ::DID.equal?(original_did)
          puts ::DID.equal?(DIDKit::DID)
          puts ::DID.respond_to?(:resolve_handle)
          puts DIDKit::DID.new(#{did_string.inspect}).to_s
        RUBY

        stdout, stderr, status = Open3.capture3(RbConfig.ruby, '-I', lib_path, '-e', code)

        stderr.should == ''
        status.success?.should == true
        stdout.should == "true\nfalse\nfalse\n#{did_string}\n"
      end
    end
  end

  ['didkit', 'didkit/did', 'didkit/document', 'didkit/resolver', 'didkit/global_did'].each do |entry_point|
    context "when requiring '#{entry_point}'" do
      it 'should provide a shared resolver and use an override throughout the lookup helpers' do
        code = <<~RUBY
          require #{entry_point.inspect}
          require 'webmock'

          include WebMock::API
          WebMock.enable!

          resolver = DIDKit.default_resolver
          puts resolver.is_a?(DIDKit::Resolver)
          puts DIDKit.default_resolver.equal?(resolver)

          custom_resolver = DIDKit::Resolver.new(plc_directory: 'plc-mirror.example')
          custom_resolver.define_singleton_method(:resolve_handle_by_dns) { |domain| #{did_string.inspect} }
          DIDKit.default_resolver = custom_resolver
          puts DIDKit.default_resolver.equal?(custom_resolver)

          stub_request(:get, 'https://plc-mirror.example/#{did_string}').to_return(
            body: JSON.generate('id' => #{did_string.inspect}, 'alsoKnownAs' => ['at://dholms.xyz']),
            headers: { 'Content-Type' => 'application/did+json' }
          )

          did = DIDKit::DID.new(#{did_string.inspect})
          puts did.get_document.did
          puts DIDKit::DID.resolve_handle('dholms.xyz')
          puts did.get_verified_handle
          puts did.document.get_verified_handle

          require 'didkit'
          puts DIDKit.default_resolver.equal?(custom_resolver)
        RUBY

        stdout, stderr, status = Open3.capture3(RbConfig.ruby, '-I', lib_path, '-e', code)

        stderr.should == ''
        status.success?.should == true
        stdout.should == "true\ntrue\ntrue\n#{did_string}\n#{did_string}\ndholms.xyz\ndholms.xyz\ntrue\n"
      end
    end
  end
end
