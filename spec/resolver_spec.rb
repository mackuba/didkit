describe DIDKit::Resolver do
  let(:sample_did) { 'did:plc:qhfo22pezo44fa3243z2h4ny' }

  describe '#resolve_handle' do
    context 'when handle resolves via HTTP' do
      before do
        Resolv::DNS.stubs(:open).returns([])
      end

      let(:handle) { 'barackobama.bsky.social' }

      it 'should return a matching DID' do
        stub_request(:get, "https://#{handle}/.well-known/atproto-did")
          .to_return(body: sample_did)

        result = subject.resolve_handle(handle)

        result.should_not be_nil
        result.should be_a(DID)
        result.to_s.should == sample_did
        result.resolved_by.should == :http
      end

      it 'should check DNS first' do
        Resolv::DNS.expects(:open).returns([])
        stub_request(:get, "https://#{handle}/.well-known/atproto-did")
          .to_return(body: sample_did)

        result = subject.resolve_handle(handle)
      end

      context 'when HTTP returns invalid text' do
        it 'should return nil' do
          stub_request(:get, "https://#{handle}/.well-known/atproto-did")
            .to_return(body: "Welcome to nginx!")

          result = subject.resolve_handle(handle)
          result.should be_nil
        end
      end

      context 'when HTTP returns bad response' do
        it 'should return nil' do
          stub_request(:get, "https://#{handle}/.well-known/atproto-did")
            .to_return(status: 400, body: sample_did)

          result = subject.resolve_handle(handle)
          result.should be_nil
        end
      end

      context 'when HTTP throws an exception' do
        it 'should catch it and return nil' do
          stub_request(:get, "https://#{handle}/.well-known/atproto-did")
            .to_raise(Errno::ETIMEDOUT)

          result = 0

          expect {
            result = subject.resolve_handle(handle)
          }.to_not raise_error

          result.should be_nil
        end
      end

      context 'when HTTP response has a trailing newline' do
        it 'should accept it' do
          stub_request(:get, "https://#{handle}/.well-known/atproto-did")
            .to_return(body: sample_did + "\n")

          result = subject.resolve_handle(handle)

          result.should_not be_nil
          result.should be_a(DID)
          result.to_s.should == sample_did
        end
      end
    end

    context 'when handle has a leading @' do
      let(:handle) { '@pfrazee.com' }

      before do
        Resolv::DNS.stubs(:open).returns([])
      end

      it 'should also return a matching DID' do
        stub_request(:get, "https://pfrazee.com/.well-known/atproto-did")
          .to_return(body: sample_did)

        result = subject.resolve_handle(handle)

        result.should_not be_nil
        result.should be_a(DID)
        result.to_s.should == sample_did
        result.resolved_by.should == :http
      end
    end

    context 'when handle has a reserved TLD' do
      let(:handle) { 'example.test' }

      it 'should return nil' do
        subject.resolve_handle(handle).should be_nil
      end
    end

    context 'when a DID string is passed' do
      let(:handle) { BSKY_APP_DID }

      it 'should return that DID' do
        result = subject.resolve_handle(handle)

        result.should be_a(DID)
        result.to_s.should == BSKY_APP_DID
      end
    end

    context 'when a DID object is passed' do
      let(:handle) { DID.new(BSKY_APP_DID) }

      it 'should return a new DID object with that DID' do
        result = subject.resolve_handle(handle)

        result.should be_a(DID)
        result.to_s.should == BSKY_APP_DID
        result.equal?(handle).should == false
      end
    end
  end

  describe '#resolve_did' do
    context 'when passed a did:plc string' do
      let(:did) { 'did:plc:yk4dd2qkboz2yv6tpubpc6co' }

      it 'should return a parsed DID document object' do
        stub_request(:get, "https://plc.directory/#{did}")
          .to_return(body: load_did_file('dholms.json'), headers: { 'Content-Type': 'application/did+ld+json; charset=utf-8' })

        result = subject.resolve_did(did)
        result.should be_a(DIDKit::Document)
        result.handles.should == ['dholms.xyz']
        result.pds_endpoint.should == 'https://pds.dholms.xyz'
      end

      it 'should require a valid content type' do
        stub_request(:get, "https://plc.directory/#{did}")
          .to_return(body: load_did_file('dholms.json'), headers: { 'Content-Type': 'text/plain' })

        expect { subject.resolve_did(did) }.to raise_error(DIDKit::APIError)
      end
    end

    context 'when passed a did:web string' do
      let(:did) { 'did:web:witchcraft.systems' }

      it 'should return a parsed DID document object' do
        stub_request(:get, "https://witchcraft.systems/.well-known/did.json")
          .to_return(body: load_did_file('witchcraft.json'), headers: { 'Content-Type': 'application/did+ld+json; charset=utf-8' })

        result = subject.resolve_did(did)
        result.should be_a(DIDKit::Document)
        result.handles.should == ['witchcraft.systems']
        result.pds_endpoint.should == 'https://pds.witchcraft.systems'
      end

      it 'should NOT require a valid content type' do
        stub_request(:get, "https://witchcraft.systems/.well-known/did.json")
          .to_return(body: load_did_file('witchcraft.json'), headers: { 'Content-Type': 'text/plain' })

        result = subject.resolve_did(did)
        result.should be_a(DIDKit::Document)
        result.handles.should == ['witchcraft.systems']
        result.pds_endpoint.should == 'https://pds.witchcraft.systems'
      end
    end
  end
end
