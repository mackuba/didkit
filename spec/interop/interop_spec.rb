require_relative 'sectioned_file'
require_relative 'unsectioned_file'

require 'json'

describe 'ATProto interop' do
  def load_json(filename)
    JSON.parse(File.read(File.join(__dir__, filename)))
  end

  let(:did_syntax_valid) { UnsectionedFile.new('syntax/did_syntax_valid.txt') }
  let(:did_syntax_invalid) { UnsectionedFile.new('syntax/did_syntax_invalid.txt') }
  let(:handle_syntax_valid) { UnsectionedFile.new('syntax/handle_syntax_valid.txt') }
  let(:handle_syntax_invalid) { UnsectionedFile.new('syntax/handle_syntax_invalid.txt') }
  let(:atidentifier_syntax_valid) { SectionedFile.new('syntax/atidentifier_syntax_valid.txt') }
  let(:atidentifier_syntax_invalid) { SectionedFile.new('syntax/atidentifier_syntax_invalid.txt') }

  let(:valid_dids) { did_syntax_valid.lines + atidentifier_syntax_valid.get('allows valid DIDs') }
  let(:invalid_dids) { did_syntax_invalid.lines + atidentifier_syntax_invalid.get('invalid DIDs') }

  let(:valid_handles) { handle_syntax_valid.lines + atidentifier_syntax_valid.get('allows valid handles') }
  let(:invalid_handles) { handle_syntax_invalid.lines + atidentifier_syntax_invalid.get('invalid handles') }

  let(:valid_did_plc) { valid_dids.select { |x| x.start_with?('did:plc:') }}
  let(:valid_did_web) { valid_dids.select { |x| x.start_with?('did:web:') }}
  let(:valid_other)   { valid_dids.reject { |x| x.start_with?('did:plc:') || x.start_with?('did:web:') }}

  describe 'DIDKit::HANDLE_REGEXP' do
    it 'should accept valid handles' do
      valid_handles.each do |line|
        line.should match(DIDKit::HANDLE_REGEXP)
      end
    end

    it 'should reject invalid handles' do
      invalid_handles.each do |line|
        if line.length <= DIDKit::MAX_HANDLE_LENGTH
          line.should_not match(DIDKit::HANDLE_REGEXP)
        end
      end
    end
  end

  describe 'DIDs' do
    it 'should accept valid did:plc DIDs' do
      valid_did_plc.each do |line|
        expect { DID.new(line) }.to_not raise_error
      end
    end

    it 'should accept valid did:web DIDs' do
      valid_did_web.each do |line|
        expect { DID.new(line) }.to_not raise_error
      end
    end

    it 'should reject invalid DIDs' do
      invalid_dids.each do |line|
        expect { DID.new(line) }.to raise_error(DIDKit::DIDError)
      end
    end

    it 'should reject valid DIDs of unsupported methods' do
      valid_other.each do |line|
        expect { DID.new(line) }.to raise_error(DIDKit::DIDError)
      end
    end
  end

  describe 'GENERIC_DID_REGEXP' do
    it 'should accept valid DIDs' do
      (valid_did_plc + valid_did_web).each do |line|
        line.should match(DIDKit::GENERIC_DID_REGEXP)
      end
    end

    it 'should accept valid DIDs of unsupported methods' do
      valid_other.each do |line|
        line.should match(DIDKit::GENERIC_DID_REGEXP)
      end
    end

    it 'should reject syntactically invalid DIDs' do
      invalid_dids.each do |line|
        if line.length <= DIDKit::MAX_DID_LENGTH
          line.should_not match(DIDKit::GENERIC_DID_REGEXP)
        end
      end
    end
  end

  describe 'public keys' do
    let(:signature_fixtures) { load_json('crypto/signature-fixtures.json') }
    let(:w3c_didkey_K256) { load_json('crypto/w3c_didkey_K256.json') }
    let(:w3c_didkey_P256) { load_json('crypto/w3c_didkey_P256.json') }

    it 'should accept valid public keys' do
      signature_fixtures.each do |json|
        key = json['publicKeyDid'].gsub(/\Adid:key:/, '')

        expect { DIDKit::PublicKey.new(key) }.to_not raise_error
      end

      w3c_didkey_K256.each do |json|
        key = json['publicDidKey'].gsub(/\Adid:key:/, '')

        expect { DIDKit::PublicKey.new(key) }.to_not raise_error
      end

      w3c_didkey_P256.each do |json|
        key = json['publicDidKey'].gsub(/\Adid:key:/, '')

        expect { DIDKit::PublicKey.new(key) }.to_not raise_error
      end
    end
  end
end
