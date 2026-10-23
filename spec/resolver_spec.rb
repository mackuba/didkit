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
        request.should have_been_requested.once
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

    it 'should reject arguments other than a String or a DID object without making a lookup' do
      Resolv::DNS.expects(:open).never

      [nil, false, true, 123, :handle, [], {}, Object.new].each do |value|
        [true, false].each do |verify|
          expect { subject.resolve_handle(value, verify: verify) }.to raise_error(
            ArgumentError, 'handle argument should be a String or a DID object'
          )
        end
      end

      WebMock.should_not have_requested(:any, /.*/)
    end

    it 'should reject syntactically invalid handles without making a lookup' do
      Resolv::DNS.expects(:open).never

      [
        '', 'com', '.example.com', 'example.com.', 'example..com', 'bücher.de',
        '-example.com', 'example-.com', 'ex_ample.com', 'example.123', 'example.3com',
        'user@example.com', 'example.com/path', 'example.com?query', 'example.com#fragment',
        ' example.com', 'example.com ', "example.com\n", 'a' * 64 + '.com',
        'localhost', 'localhost:3000', 'example.com:443',
      ].each do |handle|
        subject.resolve_handle(handle).should be_nil
      end

      WebMock.should_not have_requested(:any, /.*/)
    end

    it 'should resolve a 253-character handle with or without a leading @' do
      handle = (['a' * 63] * 3 + ['b' * 61]).join('.')
      handle.length.should == 253

      Resolv::DNS.expects(:open).twice.returns([Resolv::DNS::Resource::IN::TXT.new("did=#{sample_did}")])

      [handle, "@#{handle}"].each do |value|
        result = subject.resolve_handle(value, verify: false)
        result.to_s.should == sample_did
        result.resolved_by.should == :dns
      end
    end

    it 'should reject a 254-character handle even when its labels are valid' do
      handle = (['a' * 63] * 3 + ['b' * 62]).join('.')
      handle.length.should == 254
      handle.should match(DIDKit::HANDLE_REGEXP)

      Resolv::DNS.expects(:open).never

      subject.resolve_handle(handle).should be_nil

      WebMock.should_not have_requested(:any, /.*/)
    end

    it 'should lowercase the handle before querying DNS and verifying its reverse mapping' do
      dns = Resolv::DNS.new

      Resolv::DNS.expects(:new).with(anything).returns(dns)
      dns.expects(:getresources).with('_atproto.dholms.xyz', Resolv::DNS::Resource::IN::TXT)
        .returns([Resolv::DNS::Resource::IN::TXT.new("did=#{sample_did}")])

      result = subject.resolve_handle('@Dholms.XYZ')

      result.to_s.should == sample_did
      result.resolved_by.should == :dns
      document_request.should have_been_requested.once
    end

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

          it 'should look up a lowercased handle string in the DID doc when verifying' do
            result = subject.resolve_handle("@#{handle.upcase}")

            result.to_s.should == sample_did
            result.resolved_by.should == method
            document_request.should have_been_requested.once
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
            let(:document_json) {{
              'id' => sample_did,
              'alsoKnownAs' => [
                'https://example.com', 'at://bad_handle', 'at://example.com?query', "at://#{handle}"
              ]
            }}

            it 'should accept the first valid AT Protocol handle' do
              subject.resolve_handle(handle).should == sample_did
            end
          end

          context 'when alsoKnownAs contains the handle in mixed case' do
            let(:document_json) {{ 'id' => sample_did, 'alsoKnownAs' => ['at://Dholms.XYZ'] }}

            it 'should verify the handle regardless of the case' do
              result = subject.resolve_handle(handle)

              result.should == sample_did
              result.resolved_by.should == method
              document_request.should have_been_requested.once
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

      it "should return nil when HTTP returns a DID that is not valid in ATProto" do
        [
          'did:plc:short', 'did:web:example.invalid', 'did:web:example.com:user', 'did:web:localhost%3A65536',
          'did:web:example%GG.com', 'did:key:zQ3shqwJEJyMBsBXCWyCBpUBMqxcon9oHB7mCvx4sSpMdLJwc',
          'did:web:' + (['a' * 63] * 33).join('.'),
        ].each do |value|
          value.should match(DIDKit::GENERIC_DID_REGEXP)
          stub_request(:get, "https://#{handle}/.well-known/atproto-did").to_return(body: value)

          subject.resolve_handle_by_well_known(handle).should be_nil
          subject.resolve_handle(handle).should be_nil
          subject.resolve_handle(handle, verify: false).should be_nil
        end

        document_request.should_not have_been_requested
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

      it 'should reject uppercase and mixed-case reserved TLDs before making any lookups' do
        Resolv::DNS.expects(:open).never

        DIDKit::RESERVED_DOMAINS.each do |tld|
          [tld.upcase, tld.capitalize].each do |suffix|
            handle = "example.#{suffix}"

            subject.resolve_handle(handle).should be_nil
            WebMock.should_not have_requested(:any, /.*/)
          end
        end
      end
    end

    context 'when multiple DNS TXT records reference conflicting DIDs' do
      let(:records) {[
        "did=did:web:example.com", "did=did:plc:oio4hkxaop4ao4wz2pp3f4cr"
      ]}

      before do
        Resolv::DNS.stubs(:open).returns(records.map { |r| Resolv::DNS::Resource::IN::TXT.new(r) })
      end

      it 'should fall back to HTTPS and verify the DID it returns' do
        request = stub_request(:get, "https://#{handle}/.well-known/atproto-did").to_return(body: sample_did)

        result = subject.resolve_handle(handle)

        result.to_s.should == sample_did
        result.resolved_by.should == :http
        request.should have_been_requested.once
        document_request.should have_been_requested.once
      end

      it 'should return nil when HTTPS cannot resolve the ambiguity' do
        request = stub_request(:get, "https://#{handle}/.well-known/atproto-did").to_return(status: 404)

        subject.resolve_handle(handle).should be_nil
        request.should have_been_requested.once
        document_request.should_not have_been_requested
      end
    end

    it 'should fall back to HTTPS when DNS only contains invalid DID values' do
      Resolv::DNS.stubs(:open).returns([Resolv::DNS::Resource::IN::TXT.new('did=did:plc:short')])

      request = stub_request(:get, "https://#{handle}/.well-known/atproto-did").to_return(body: sample_did)

      subject.resolve_handle(handle).resolved_by.should == :http
      request.should have_been_requested.once
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

  describe '#resolve_handle_by_dns' do
    let(:records) { [] }

    before { Resolv::DNS.stubs(:open).returns(records) }

    it 'should concatenate all chunks of a TXT record before parsing the DID' do
      records << Resolv::DNS::Resource::IN::TXT.new('d', 'id=did:plc:', sample_did.delete_prefix('did:plc:'))

      subject.resolve_handle_by_dns('example.com').should == sample_did
    end

    it 'should ignore unrelated and malformed records before and after a valid DID' do
      records.concat([
        Resolv::DNS::Resource::IN::TXT.new('foobar'),
        Resolv::DNS::Resource::IN::TXT.new('did=not-a-did'),
        Resolv::DNS::Resource::IN::TXT.new('did=did:plc:short'),
        Resolv::DNS::Resource::IN::TXT.new("did=#{sample_did}"),
        Resolv::DNS::Resource::IN::TXT.new('did=did:web:example.com/path'),
        Resolv::DNS::Resource::IN::TXT.new('other=value')
      ])

      subject.resolve_handle_by_dns('example.com').should == sample_did
    end

    it 'should accept multiple records when all valid records identify the same DID' do
      records << Resolv::DNS::Resource::IN::TXT.new("did=#{sample_did}")
      records << Resolv::DNS::Resource::IN::TXT.new('did=', sample_did)

      subject.resolve_handle_by_dns('example.com').should == sample_did
    end

    it 'should reject different DIDs regardless of record order' do
      records << Resolv::DNS::Resource::IN::TXT.new("did=#{sample_did}")
      records << Resolv::DNS::Resource::IN::TXT.new('did=did:plc:oio4hkxaop4ao4wz2pp3f4cr')

      subject.resolve_handle_by_dns('example.com').should be_nil
      records.reverse!
      subject.resolve_handle_by_dns('example.com').should be_nil
    end

    it 'should return nil when there are no TXT records' do
      subject.resolve_handle_by_dns('example.com').should be_nil
    end

    it 'should return nil when no record contains a valid DID' do
      ['unrelated=value', 'did=', 'did=did:plc:short', "did=#{sample_did}\n"].each do |value|
        records << Resolv::DNS::Resource::IN::TXT.new(value)
      end

      subject.resolve_handle_by_dns('example.com').should be_nil
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

      it 'should resolve localhost without an explicit port over HTTP' do
        did = 'did:web:localhost'

        request = stub_request(:get, 'http://localhost/.well-known/did.json')
          .to_return(body: JSON.generate('id' => did), headers: { 'Content-Type' => 'application/did+json' })

        subject.resolve_did(did).did.to_s.should == did
        request.should have_been_requested.once
      end

      it "should resolve DIDs using the percent-decoded host" do
        {
          'did:web:%65xample%2ecom' => 'https://example.com',
          'did:web:loc%61lhost%3a%33%30%30%30' => 'http://localhost:3000'
        }.each do |did, host|
          request = stub_request(:get, "#{host}/.well-known/did.json")
            .to_return(body: JSON.generate('id' => did), headers: { 'Content-Type' => 'application/did+json' })

          subject.resolve_did(did).did.to_s.should == did
          request.should have_been_requested.once
        end
      end

      it 'should fetch did.json over HTTP using the decoded port' do
        [1, 3000, 65535].each do |port|
          did = "did:web:localhost%3A#{port}"
          json = load_did_json('witchcraft.json').merge('id' => did)

          request = stub_request(:get, "http://localhost:#{port}/.well-known/did.json")
            .to_return(body: JSON.generate(json), headers: { 'Content-Type' => 'application/did+json' })

          document = subject.resolve_did(did)

          document.should be_a(DIDKit::Document)
          document.did.to_s.should == did
          request.should have_been_requested.once
        end
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

    it "should return nil if the first handle doesn't resolve to the DID" do
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
