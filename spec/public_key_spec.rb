# frozen_string_literal: true

describe DIDKit::PublicKey do
  subject { described_class }

  let(:k256_multibase) { 'zQ3shqwJEJyMBsBXCWyCBpUBMqxcon9oHB7mCvx4sSpMdLJwc' }
  let(:p256_multibase) { 'zDnaembgSGUhZULN2Caob4HLJPaxBh92N7rtH21TErzqf8HQo' }

  def encode_multibase(bytes)
    "z#{Base58.binary_to_base58(bytes, :bitcoin, true)}"
  end

  describe '#initialize' do
    context 'with a K-256 key' do
      it 'should decode the key data successfully' do
        key = subject.new(k256_multibase)

        key.multibase.should == k256_multibase
        key.type.should == :k256
        key.compressed_key.unpack1('H*').should == '03a7d7fbf04846fa1fcff728ba594f3c5819345e88908e874b537ba5a65d1fc3bb'
        key.compressed_key.bytesize.should == 33
      end

      it 'should create a secp256k1 OpenSSL group and point' do
        key = subject.new(k256_multibase)

        key.ec_group.should be_an(OpenSSL::PKey::EC::Group)
        key.ec_group.curve_name.should == 'secp256k1'

        key.ec_point.should be_an(OpenSSL::PKey::EC::Point)
        key.ec_point.should be_on_curve
        key.ec_point.to_octet_string(:compressed).should == key.compressed_key
      end
    end

    context 'with a P-256 key' do
      it 'should decode the key data successfully' do
        key = subject.new(p256_multibase)

        key.multibase.should == p256_multibase
        key.type.should == :p256
        key.compressed_key.unpack1('H*').should == '033a8273eece6b0d82e95c3506617db5000e14ff0023325d0bb0274918bc6a6cdc'
        key.compressed_key.bytesize.should == 33
      end

      it 'should create a prime256v1 OpenSSL group and point' do
        key = subject.new(p256_multibase)

        key.ec_group.should be_an(OpenSSL::PKey::EC::Group)
        key.ec_group.curve_name.should == 'prime256v1'

        key.ec_point.should be_an(OpenSSL::PKey::EC::Point)
        key.ec_point.should be_on_curve
        key.ec_point.to_octet_string(:compressed).should == key.compressed_key
      end
    end

    context 'when the argument is not a string' do
      it 'should raise an argument error' do
        expect { subject.new(123) }.to raise_error(ArgumentError, 'Expected a string argument')
      end
    end

    context 'when the multibase encoding is not Base58' do
      it 'should raise a key error' do
        key = k256_multibase.dup
        key[0] = 'x'

        expect { subject.new(key) }.to raise_error(DIDKit::KeyError, /Unsupported key encoding/)
      end
    end

    context 'when the Base58 data is invalid' do
      it 'should raise a key error' do
        expect { subject.new('z0') }.to raise_error(DIDKit::KeyError, 'Invalid Base58 encoding in key data')
      end
    end

    context 'when the key uses an unsupported multicodec key' do
      it 'should raise a key error' do
        encoded = encode_multibase("\x00\x00".b + "\x02".b + ("\x01".b * 32))

        expect { subject.new(encoded) }.to raise_error(DIDKit::KeyError, /Unsupported key type/)
      end
    end

    context 'when the decoded key has an invalid length' do
      it 'should raise a key error' do
        encoded = encode_multibase(DIDKit::PublicKey::K256_PREFIX + "\x02".b + ("\x01".b * 31))

        expect { subject.new(encoded) }.to raise_error(DIDKit::KeyError, 'Invalid key length (34)')
      end
    end

    context 'when OpenSSL cannot decode the compressed point' do
      it 'should raise a key error' do
        encoded = encode_multibase(DIDKit::PublicKey::K256_PREFIX + "\x02".b + ("\xFF".b * 32))

        expect { subject.new(encoded) }.to raise_error(DIDKit::KeyError, /Invalid key data/)
      end
    end

    context "when the key's elliptic curve point is outside the curve" do
      it 'should raise a key error' do
        point = mock('EC point')
        point.stubs(:on_curve?).returns(false)
        OpenSSL::PKey::EC::Point.stubs(:new).returns(point)

        expect { subject.new(k256_multibase) }.to raise_error(DIDKit::KeyError, /Invalid key data/)
      end
    end
  end
end
