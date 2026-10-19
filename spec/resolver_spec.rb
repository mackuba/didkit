describe DIDKit::Resolver do
  let(:sample_did) { 'did:plc:qhfo22pezo44fa3243z2h4ny' }

  describe '#initialize' do
    [
      'https://plc-mirror.example',
      'https://plc-mirror.example/',
      'https://plc-mirror.example:8443/',
      'plc.directory',
      'plc-mirror.example:8443',
      'plc-mirror.example:8443/',
      'localhost:3000',
      '127.0.0.1:3000',
      '[::1]:3000',
      'http://localhost:3000',
      'http://LOCALHOST:3000/',
      'http://127.0.0.1:3000/',
      'http://127.42.0.2:3000',
      'http://[::1]:3000/',
      'https://[2001:db8::1]:8443'
    ].each do |url|
      it "should resolve PLC DIDs using #{url}" do
        did = 'did:plc:yk4dd2qkboz2yv6tpubpc6co'
        base_url = url.include?('://') ? url : "https://#{url}"

        request = stub_request(:get, "#{base_url.delete_suffix('/')}/#{did}")
          .to_return(body: load_did_file('dholms.json'), headers: { 'Content-Type': 'application/did+ld+json' })

        resolver = described_class.new(plc_directory: url)
        result = resolver.resolve_did(did)

        result.should be_a(DIDKit::Document)
        result.did.to_s.should == did
        result.handles.should == ['dholms.xyz']
        expect(request).to have_been_requested.once
      end
    end

    [
      'http://plc-mirror.example',
      'http://localhost.example',
      'http://192.168.1.1',
      'http://0.0.0.0',
      'http://128.0.0.1',
      'http://[::]',
      'http://[2001:db8::1]',
      'ftp://localhost',
      '//plc.directory',
      'plc.directory/a',
      'plc.directory:8443/a',
      'plc.directory?query=value',
      'plc.directory#fragment',
      'user:password@plc.directory',
      'plc.directory:invalid',
      'https://',
      'https://plc.directory/a',
      'https://plc.directory//',
      'http://localhost:3000/a',
      'https://plc.directory/%2F',
      'https://plc.directory?query=value',
      'https://plc.directory/#fragment',
      'https://user:password@plc.directory',
      'https://plc.directory:invalid',
      'not a URL',
      '',
      false,
      123,
      URI('https://plc.directory')
    ].each do |url|
      it "should reject an invalid PLC directory URL: #{url.inspect}" do
        expect { described_class.new(plc_directory: url) }.to raise_error(ArgumentError)
      end
    end
  end

  describe '#resolve_handle' do
    let(:handle) { 'dholms.xyz' }
    let(:plc_directory) { 'https://plc.directory' }
    let(:document_json) {{ 'id' => sample_did, 'alsoKnownAs' => ["at://#{handle.to_s.delete_prefix('@')}"] }}

    let(:document_request) {
      stub_request(:get, "#{plc_directory}/#{sample_did}")
        .to_return(body: JSON.generate(document_json), headers: { 'Content-Type' => 'application/did+json' })
    }

    before { document_request }

    [:dns, :http].each do |method|
      context "when resolving a handle that is verified by #{method}" do
        let(:plc_directory) { 'https://plc-mirror.example' }

        subject { described_class.new(plc_directory: plc_directory) }

        before do
          if method == :dns
            Resolv::DNS.stubs(:open).returns([Resolv::DNS::Resource::IN::TXT.new("did=#{sample_did}")])
          else
            Resolv::DNS.stubs(:open).returns([])
            stub_request(:get, "https://#{handle}/.well-known/atproto-did").to_return(body: sample_did)
          end
        end

        context 'with default verify setting' do
          it 'should verify that the resolved DID has this handle assigned in DID document' do
            result = subject.resolve_handle(handle)

            result.should == sample_did
            result.resolved_by.should == method

            document_request.should have_been_requested.once
          end

          it 'should look up the DID document in the configured PLC directory mirror' do
            WebMock.should_not have_requested(:get, "https://plc.directory/#{sample_did}")          
          end          

          context 'when the DID has a different handle assigned' do
            let(:document_json) {{ 'id' => sample_did, 'alsoKnownAs' => ['at://other.example'] }}

            it 'should return nil' do
              subject.resolve_handle(handle).should be_nil

              document_request.should have_been_requested.once
            end
          end

          context 'when the DID has no handles' do
            let(:document_json) {{ 'id' => sample_did }}

            it 'should return nil' do
              subject.resolve_handle(handle).should be_nil
            end
          end

          context 'when the matching handle is not the primary handle' do
            let(:document_json) {
              { 'id' => sample_did, 'alsoKnownAs' => ['at://other.example', "at://#{handle}"] }
            }

            it 'should return nil even though the handle appears in alsoKnownAs' do
              subject.resolve_handle(handle).should be_nil
            end
          end

          context 'when alsoKnownAs contains unrelated URIs before the primary handle' do
            let(:document_json) {
              { 'id' => sample_did, 'alsoKnownAs' => ['https://example.com', "at://#{handle}"] }
            }

            it 'should accept the first valid AT Protocol handle' do
              subject.resolve_handle(handle).should == sample_did
            end
          end
        end

        context 'with explicit verify: true' do
          it 'should verify that the resolved DID has this handle assigned in DID document' do
            result = subject.resolve_handle(handle, verify: true)

            result.should == sample_did
            result.resolved_by.should == method

            document_request.should have_been_requested.once
          end          
        end

        context 'with verify: false' do
          context 'when the DID has a different handle assigned' do
            let(:document_json) {{ 'id' => sample_did, 'alsoKnownAs' => ['at://other.example'] }}

            it 'should not verify the handle bi-directionally and accept the assigned DID' do
              result = subject.resolve_handle(handle, verify: false)

              result.should == sample_did
              result.resolved_by.should == method

              document_request.should_not have_been_requested
            end
          end          
        end
      end
    end

    context 'when the handle resolves to a did:web' do
      let(:sample_did) { 'did:web:witchcraft.systems' }

      before do
        Resolv::DNS.stubs(:open).returns([Resolv::DNS::Resource::IN::TXT.new("did=#{sample_did}")])

        stub_request(:get, 'https://witchcraft.systems/.well-known/did.json')
          .to_return(body: JSON.generate(document_json), headers: { 'Content-Type' => 'application/json' })
      end

      it 'should load the DID document to verify the handle in from the did:web domain' do
        subject.resolve_handle(handle).should == sample_did

        document_request.should_not have_been_requested
      end
    end

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

        document_request.should_not have_been_requested
      end
    end

    context 'when a DID object is passed' do
      let(:handle) { DID.new(BSKY_APP_DID) }

      it 'should return a new DID object with that DID' do
        result = subject.resolve_handle(handle)

        result.should be_a(DID)
        result.to_s.should == BSKY_APP_DID
        result.equal?(handle).should == false

        document_request.should_not have_been_requested
      end
    end
  end

  describe '#resolve_did' do
    context 'when passed a did:plc string' do
      let(:did) { 'did:plc:yk4dd2qkboz2yv6tpubpc6co' }

      [
        'application/did+ld+json',
        'application/did+ld+json; charset=utf-8',
        'application/did+json',
        'application/did+json; charset=utf-8'
      ].each do |content_type|
        it "should return a parsed DID document for #{content_type}" do
          json = load_did_json('dholms.json')
          json.delete('@context') if content_type.start_with?('application/did+json')
          stub_request(:get, "https://plc.directory/#{did}")
            .to_return(body: JSON.generate(json), headers: { 'Content-Type' => content_type })

          result = subject.resolve_did(did)
          result.should be_a(DIDKit::Document)
          result.handles.should == ['dholms.xyz']
          result.pds_endpoint.should == 'https://pds.dholms.xyz'
        end
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

  describe '#get_verified_handle' do
    let(:did) { DID.new('did:plc:yk4dd2qkboz2yv6tpubpc6co') }
    let(:base_json) { load_did_json('dholms.json') }
    let(:json) { base_json.merge('alsoKnownAs' => [
      "mozilla.org",
      "at://dholms.xyz",
      "at://dholms.bsky.team"
    ])}

    before do
      stub_request(:get, "https://plc.directory/#{did}")
        .to_return(body: JSON.generate(json), headers: { 'Content-Type': 'application/did+ld+json; charset=utf-8' })
    end

    it 'should return first syntactically correct handle if it resolves back to the DID' do
      DIDKit::Resolver.any_instance.stubs(:resolve_handle).with('dholms.xyz', verify: false).returns(did.to_s)

      subject.get_verified_handle(did).should == 'dholms.xyz'
    end

    it "should return nil if the first handle doesn't validate" do
      DIDKit::Resolver.any_instance.stubs(:resolve_handle).with('dholms.xyz', verify: false).returns('')

      subject.get_verified_handle(did).should be_nil
    end

    it 'should not re-fetch the already fetched DID document to verify the handle bi-directionally' do
      Resolv::DNS.stubs(:open).returns([Resolv::DNS::Resource::IN::TXT.new("did=#{did}")])

      subject.get_verified_handle(did).should == 'dholms.xyz'
      WebMock.should have_requested(:get, "https://plc.directory/#{did}").once
    end

    context 'if there are no syntactically valid handles' do
      let(:json) { base_json.merge('alsoKnownAs' => ["mozilla.org"])}

      it "should return nil" do
        subject.get_verified_handle(did).should be_nil
      end
    end
  end
end
