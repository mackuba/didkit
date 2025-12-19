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

  describe 'account status' do
    let(:document) { stub(:pds_endpoint => 'https://pds.ruby.space') }
    let(:did) { subject.new(plc_did) }

    before do
      did.stubs(:document).returns(document)

      stub_request(:get, 'https://pds.ruby.space/xrpc/com.atproto.sync.getRepoStatus')
        .with(query: { did: plc_did })
        .to_return(http_response) if defined?(http_response)
    end

    context 'when repo is active' do
      let(:http_response) {
        { body: { active: true }.to_json, headers: { 'Content-Type' => 'application/json' }}
      }

      it 'should report active account state' do
        did.account_status.should == :active
        did.account_active?.should == true
        did.account_exists?.should == true
      end
    end

    context 'when repo is inactive' do
      let(:http_response) {
        { body: { active: false, status: 'takendown' }.to_json, headers: { 'Content-Type' => 'application/json' }}
      }

      it 'should report an inactive existing account' do
        did.account_status.should == :takendown
        did.account_active?.should == false
        did.account_exists?.should == true
      end
    end

    context 'when repo is not found' do
      let(:http_response) {
        { status: 400, body: { error: 'RepoNotFound' }.to_json, headers: { 'Content-Type' => 'application/json' }}
      }

      it 'should return nil status and report the account as missing' do
        did.account_status.should be_nil
        did.account_active?.should == false
        did.account_exists?.should == false
      end
    end

    context 'when the document has no pds endpoint' do
      before do
        did.stubs(:document).returns(stub(:pds_endpoint => nil))
      end

      it 'should return nil status and report the account as missing' do
        did.account_status.should be_nil
        did.account_active?.should == false
        did.account_exists?.should == false
      end
    end

    context 'when active field is not set' do
      let(:http_response) {
        { body: { active: nil, status: 'unknown' }.to_json, headers: { 'Content-Type' => 'application/json' }}
      }

      it 'should raise APIError' do
        expect { did.account_status }.to raise_error(DIDKit::APIError)
        expect { did.account_active? }.to raise_error(DIDKit::APIError)
        expect { did.account_exists? }.to raise_error(DIDKit::APIError)
      end
    end

    context 'when active is false but status is not set' do
      let(:http_response) {
        { body: { active: false, status: nil }.to_json, headers: { 'Content-Type' => 'application/json' }}
      }

      it 'should raise APIError' do
        expect { did.account_status }.to raise_error(DIDKit::APIError)
        expect { did.account_active? }.to raise_error(DIDKit::APIError)
        expect { did.account_exists? }.to raise_error(DIDKit::APIError)
      end
    end

    context 'when an error different than RepoNotFound is returned' do
      let(:http_response) {
        { status: 400, body: { error: 'UserIsJerry' }.to_json, headers: { 'Content-Type' => 'application/json' }}
      }

      it 'should raise APIError' do
        expect { did.account_status }.to raise_error(DIDKit::APIError)
        expect { did.account_active? }.to raise_error(DIDKit::APIError)
        expect { did.account_exists? }.to raise_error(DIDKit::APIError)
      end
    end

    context 'when the response is not application/json' do
      let(:http_response) {
        { status: 400, body: 'error', headers: { 'Content-Type' => 'text/html' }}
      }

      it 'should raise APIError' do
        expect { did.account_status }.to raise_error(DIDKit::APIError)
        expect { did.account_active? }.to raise_error(DIDKit::APIError)
        expect { did.account_exists? }.to raise_error(DIDKit::APIError)
      end
    end

    context 'when the response is not 200 or 400' do
      let(:http_response) {
        { status: 500, body: { error: 'RepoNotFound' }.to_json, headers: { 'Content-Type' => 'application/json' }}
      }

      it 'should raise APIError' do
        expect { did.account_status }.to raise_error(DIDKit::APIError)
        expect { did.account_active? }.to raise_error(DIDKit::APIError)
        expect { did.account_exists? }.to raise_error(DIDKit::APIError)
      end
    end
  end
end
