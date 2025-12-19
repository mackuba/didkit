describe DIDKit::DID do
  subject { described_class }

  let(:plc_did) { 'did:plc:vc7f4oafdgxsihk4cry2xpze' }
  let(:web_did) { 'did:web:taylorswift.com' }

  describe '#initialize' do
    context 'with a valid did:plc' do
      it 'should return an initialized DID object' do
        did = subject.new(plc_did)

        did.should be_a(DIDKit::DID)
        did.type.should == :plc
        did.did.should be_a(String)
        did.did.should == plc_did
        did.resolved_by.should be_nil
      end
    end

    context 'with a valid did:web' do
      it 'should return an initialized DID object' do
        did = subject.new(web_did)

        did.should be_a(DIDKit::DID)
        did.type.should == :web
        did.did.should be_a(String)
        did.did.should == web_did
        did.resolved_by.should be_nil
      end
    end

    context 'with another DID object' do
      it 'should create a copy of the DID' do
        other = subject.new(plc_did)
        did = subject.new(other)

        did.did.should == plc_did
        did.type.should == :plc
        did.equal?(other).should == false
      end
    end

    context 'with a string that is not a DID' do
      it 'should raise an error' do
        expect {
          subject.new('not-a-did')
        }.to raise_error(DIDKit::DIDError)
      end
    end

    context 'when an unrecognized did: type' do
      it 'should raise an error' do
        expect {
          subject.new('did:example:123')
        }.to raise_error(DIDKit::DIDError)
      end
    end
  end

  describe '#web_domain' do
    context 'for a did:web' do
      it 'should return the domain part' do
        did = subject.new('did:web:site.example.com')

        did.web_domain.should == 'site.example.com'
      end      
    end

    context 'for a did:plc' do
      it 'should return nil' do
        did = subject.new('did:plc:yk4dd2qkboz2yv6tpubpc6co')

        did.web_domain.should be_nil
      end
    end
  end

  describe '#==' do
    let(:did_string) { 'did:plc:vc7f4oafdgxsihk4cry2xpze' }
    let(:other_string) { 'did:plc:oio4hkxaop4ao4wz2pp3f4cr' }

    let(:did) { subject.new(did_string) }
    let(:other) { subject.new(other_string) }

    context 'given a DID string' do
      it 'should compare its string value to the other DID' do
        did.should == did_string
        did.should_not == other_string
      end
    end

    context 'given another DID object' do
      it "should compare its string value to the other DID's string value" do
        copy = subject.new(did_string)

        did.should == copy
        did.should_not == other
      end
    end

    context 'given something that is not a DID' do
      it 'should return false' do
        did.should_not == :didplc
        did.should_not == [did_string]
      end
    end
  end

  describe '#to_s' do
    it "should return the DID's string value" do
      did = subject.new(plc_did)

      did.to_s.should be_a(String)
      did.to_s.should == plc_did
    end
  end
end
