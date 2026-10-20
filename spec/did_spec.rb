describe DIDKit::DID do
  subject { described_class }

  let(:plc_did) { 'did:plc:vc7f4oafdgxsihk4cry2xpze' }
  let(:web_did) { 'did:web:taylorswift.com' }

  describe '#initialize' do
    it 'should reject arguments other than a String or DID object' do
      [nil, false, true, 123, :did, [], {}, Object.new].each do |value|
        expect { subject.new(value) }.to raise_error(ArgumentError, 'did should be a String or a DID object')
      end
    end

    context 'with a did:plc identifier' do
      it 'should accept did:plc: followed by exactly 24 lowercase base32 characters' do
        [
          'did:plc:oky5czdrnfjpqslsw2a5iclo',
          'did:plc:2nxcvdofca2l4l5hvguypda7',
          'did:plc:abcdefghijklmnopqrstuvwx',
          'did:plc:' + 'a' * 24,
        ].each do |value|
          did = subject.new(value)
          did.to_s.should == value
          did.type.should == :plc
        end
      end

      it 'should reject invalid lengths, uppercase letters, and characters outside base32' do
        [
          'did:plc:' + 'a' * 23,
          'did:plc:' + 'a' * 25,
          plc_did.upcase,
          'did:plc:' + 'A' * 24,
          'did:plc:' + 'a' * 23 + '0',
          'did:plc:' + 'a' * 23 + '1',
          'did:plc:' + 'a' * 23 + '8',
          'did:plc:' + 'a' * 23 + '9',
          'did:plc:' + 'a' * 23 + '_'
        ].each do |value|
          expect { subject.new(value) }.to raise_error(DIDKit::DIDError, /Invalid did:plc|Invalid DID format/)
        end
      end
    end

    context 'with a did:web identifier' do
      it 'should decode percent-escaped hostname characters and port separators' do
        {
          'did:web:%65xample%2ecom' => ['example.com', 'https://example.com'],
          'did:web:localhost%3a3000' => ['localhost', 'http://localhost:3000'],
          'did:web:loc%61lhost%3A%33%30%30%30' => ['localhost', 'http://localhost:3000']
        }.each do |value, (domain, host)|
          did = subject.new(value)

          did.to_s.should == value
          did.did_web_domain.should == domain
          did.web_domain.should == domain
          did.did_web_host.should == host
        end
      end

      it 'should reject invalid escapes and decoded characters that are invalid in a hostname' do
        %w[
          did:web:example%GG.com did:web:example%2.com did:web:example%00.com
          did:web:example%FF.com did:web:example.com%2Fpath did:web:example.com%2F
          did:web:example.com%3Fquery did:web:example.com%23fragment did:web:user%40example.com
          did:web:localhost%253A3000
        ].each do |value|
          expect { subject.new(value) }.to raise_error(DIDKit::DIDError, /Invalid did:web|Invalid DID format/)
        end
      end

      it 'should reject escapes in the first two segments of the DID string' do
        %w[
          did:w%65b:example.com di%64:web:example.com
        ].each do |value|
          expect { subject.new(value) }.to raise_error(DIDKit::DIDError, /Invalid did:web|Invalid DID format/)
        end
      end

      it 'should reject unencoded port separator' do
        expect { subject.new("did:web:localhost:1234") }.to raise_error(DIDKit::DIDError, "Invalid did:web")
      end

      it 'should ports on non-localhost domains' do
        expect { subject.new("did:web:example.com%3A443") }.to raise_error(DIDKit::DIDError, "Invalid did:web")
      end

      it 'should reject paths and other disallowed URL parts' do
        %w[
          did:web:example.com:user did:web:example.com/path did:web:example.com/
          did:web:example.com?query did:web:example.com#fragment
        ].each do |value|
          expect { subject.new(value) }.to raise_error(DIDKit::DIDError, /Invalid did:web|Invalid DID format/)
        end
      end

      it 'should reject invalid localhost ports' do
        %w[
          did:web:localhost%3A did:web:localhost%3Aabc
        ].each do |value|
          expect { subject.new(value) }.to raise_error(DIDKit::DIDError, /Invalid did:web|Invalid DID format/)
        end
      end

      it 'should reject invalid hostnames' do
        %w[
          did:web:com did:web:.example.com did:web:example.com.
          did:web:example..com did:web:-example.com did:web:example-.com
          did:web:ex_ample.com did:web:example.123 did:web:127.0.0.1
          did:web:bücher.de did:web:website
        ].each do |value|
          expect { subject.new(value) }.to raise_error(DIDKit::DIDError, /Invalid did:web|Invalid DID format/)
        end
      end

      it 'should reject hostnames with too long domain segments' do
        expect { subject.new('did:web:' + 'a' * 64 + '.com') }.to raise_error(
          DIDKit::DIDError, /Invalid did:web|Invalid DID format/
        )
      end

      it 'should reject IPs and top-level domains starting with numbers' do
        %w[
          did:web:example.123 did:web:example.3com did:web:1.1.1.1 did:web:127.0.0.1
        ].each do |value|
          expect { subject.new(value) }.to raise_error(DIDKit::DIDError, /Invalid did:web|Invalid DID format/)
        end
      end

      it 'should accept valid hostnames' do
        [
          'did:web:sub.example.com', 'did:web:my-website.org', 'did:web:xn--bcher-kva.de',
          'did:web:' + 'a' * 63 + '.com',
        ].each do |value|
          subject.new(value).to_s.should == value
        end
      end

      it 'should accept localhost with or without an encoded port' do
        %w[
          did:web:localhost did:web:localhost%3A1234
        ].each do |value|
          subject.new(value).to_s.should == value
        end
      end

      it 'should accept localhost ports up to 65535' do
        [1, 1024, 65535].each do |port|
          value = "did:web:localhost%3A#{port}"
          subject.new(value).to_s.should == value
        end
      end

      it 'should reject localhost ports outside the valid range' do
        [0, 65536, 99999, 100000].each do |port|
          expect { subject.new("did:web:localhost%3A#{port}") }.to raise_error(
            DIDKit::DIDError, /Invalid did:web( server port)?/
          )
        end
      end

      it 'should reject forbidden top-level domains regardless of case' do
        DIDKit::RESERVED_DOMAINS.each do |tld|
          [tld, tld.upcase].each do |suffix|
            expect { subject.new("did:web:example.#{suffix}") }.to raise_error(DIDKit::DIDError, /Invalid did:web TLD/)
          end
        end
      end

      it 'should allow reserved words in labels other than the top-level domain' do
        subject.new('did:web:test.example.com').did_web_domain.should == 'test.example.com'
      end

      it 'should reject DID strings longer than 2048 characters' do
        value = 'did:web:' + (['a' * 63] * 33).join('.')

        expect { subject.new(value) }.to raise_error(DIDKit::DIDError, 'DID string too long')
      end

      it 'should run validations on the percent-decoded DID host' do
        %w[did:web:example.%61rpa did:web:example%2ELOCAL did:web:localhost%3a65536].each do |value|
          expect { subject.new(value) }.to raise_error(DIDKit::DIDError, /Invalid did:web|Invalid DID format/)
        end
      end
    end

    it 'should reject whitespace in DIDs' do
      [" #{plc_did}", "#{plc_did}\n", " #{web_did}", "#{web_did}\n"].each do |value|
        expect { subject.new(value) }.to raise_error(DIDKit::DIDError, "Invalid DID format")
      end
    end

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
        expect { subject.new('not-a-did') }.to raise_error(DIDKit::DIDError, "Invalid DID format")
      end
    end

    context 'when an unrecognized did: type' do
      it 'should raise an error' do
        expect { subject.new('did:example:123') }.to raise_error(DIDKit::DIDError, /Unrecognized DID type/)
      end
    end
  end

  describe 'GENERIC_DID_REGEXP' do
    it 'should recognize valid generic syntax independently of supported DID methods' do
      %w[did:m:v did:method:val_two did:method:val:two did:method::::val did:method:val%BB].each do |value|
        value.should match(DIDKit::GENERIC_DID_REGEXP)
        expect { subject.new(value) }.to raise_error(DIDKit::DIDError, /Unrecognized DID type/)
      end
    end

    it 'should reject invalid method names, empty identifiers, and trailing separators' do
      %w[DID:method:val did:METHOD:val did:m123:val did:method: did:method:val: did:method:val%].each do |value|
        value.should_not match(DIDKit::GENERIC_DID_REGEXP)
      end
    end
  end

  describe '#did_web_domain' do
    context 'for a did:web' do
      it 'should return the domain part' do
        did = subject.new('did:web:site.example.com')

        did.did_web_domain.should == 'site.example.com'
      end

      it 'should return localhost without the encoded port' do
        subject.new('did:web:localhost%3A3000').did_web_domain.should == 'localhost'
      end
    end

    context 'for a did:plc' do
      it 'should return nil' do
        did = subject.new('did:plc:yk4dd2qkboz2yv6tpubpc6co')

        did.did_web_domain.should be_nil
      end
    end
  end

  describe '#web_domain' do
    it 'should remain an alias for did_web_domain' do
      [web_did, 'did:web:localhost', 'did:web:localhost%3A3000', plc_did].each do |value|
        did = subject.new(value)
        did.web_domain.should == did.did_web_domain
      end
    end
  end

  describe '#did_web_host' do
    it 'should use HTTPS for non-localhost domains' do
      subject.new('did:web:site.example.com').did_web_host.should == 'https://site.example.com'
      subject.new('did:web:localhost.example.com').did_web_host.should == 'https://localhost.example.com'
    end

    it 'should use HTTP for localhost without an explicit port' do
      subject.new('did:web:localhost').did_web_host.should == 'http://localhost'
    end

    it 'should use HTTP with decoded port for localhost hosts with port' do
      [1, 3000, 65535].each do |port|
        subject.new("did:web:localhost%3A#{port}").did_web_host.should == "http://localhost:#{port}"
      end
    end

    it 'should raise a DIDError for a did:plc identifier' do
      expect { subject.new(plc_did).did_web_host }.to raise_error(DIDKit::DIDError, "DID is not a did:web")
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

    context 'when repo is not found and we get a 404 response' do
      let(:http_response) {
        { status: 404, body: { error: 'RepoNotFound' }.to_json, headers: { 'Content-Type' => 'application/json' }}
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

    [400, 404].each do |status|
      context "when an error different than RepoNotFound is returned with status #{status}" do
        let(:http_response) {
          { status: status, body: { error: 'UserIsJerry' }.to_json, headers: { 'Content-Type' => 'application/json' }}
        }

        it 'should raise APIError' do
          expect { did.account_status }.to raise_error(DIDKit::APIError)
          expect { did.account_active? }.to raise_error(DIDKit::APIError)
          expect { did.account_exists? }.to raise_error(DIDKit::APIError)
        end
      end
    end

    [200, 400, 404].each do |status|
      context "when the response has status #{status} and is not application/json" do
        let(:http_response) {
          { status: status, body: 'error', headers: { 'Content-Type' => 'text/html' }}
        }

        it 'should raise APIError' do
          expect { did.account_status }.to raise_error(DIDKit::APIError)
          expect { did.account_active? }.to raise_error(DIDKit::APIError)
          expect { did.account_exists? }.to raise_error(DIDKit::APIError)
        end
      end
    end

    context 'when the response is not 200, 400, or 404' do
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

  context 'for a DID with multiple handles assigned' do
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

    describe '#get_verified_handle' do
      it 'should return first syntactically correct handle if it verifies in the other direction' do
        DIDKit::Resolver.any_instance.stubs(:resolve_handle).with('dholms.xyz', verify: false).returns(did.to_s)

        did.get_verified_handle.should == 'dholms.xyz'
      end

      it "should return nil if the first handle doesn't resolve to the same DID" do
        DIDKit::Resolver.any_instance.stubs(:resolve_handle).with('dholms.xyz', verify: false).returns('')

        did.get_verified_handle.should be_nil
      end

      context 'if there are no syntactically valid handles' do
        let(:json) { base_json.merge('alsoKnownAs' => ["mozilla.org", "firefox.com"])}

        it "should return nil" do
          did.get_verified_handle.should be_nil
        end
      end
    end
  end

  context 'with a custom default resolver' do
    let(:resolver) { DIDKit::Resolver.new(nameserver: '1.1.1.1', plc_directory: 'https://plc-mirror.example') }
    let(:did) { subject.new('did:plc:yk4dd2qkboz2yv6tpubpc6co') }

    let(:plc_request) {
      stub_request(:get, "https://plc-mirror.example/#{did}")
        .to_return(body: load_did_file('dholms.json'), headers: { 'Content-Type' => 'application/did+json' })
    }

    before do
      @original_resolver = DIDKit.default_resolver
      DIDKit.default_resolver = resolver
    end

    after do
      DIDKit.default_resolver = @original_resolver
    end

    context 'with default verification not explicitly disabled' do
      it 'should use the configured nameserver for handle resolution' do
        request = plc_request
        dns = Resolv::DNS.new(nameserver: '1.1.1.1')

        Resolv::DNS.expects(:new).with(has_entry(:nameserver, '1.1.1.1')).returns(dns)
        dns.expects(:getresources).with('_atproto.dholms.xyz', Resolv::DNS::Resource::IN::TXT)
          .returns([Resolv::DNS::Resource::IN::TXT.new("did=#{did}")])

        result = subject.resolve_handle('dholms.xyz')

        result.should == did
        result.resolved_by.should == :dns

        request.should have_been_requested.once
      end

      it 'should reject a resolved DID if it does not have the handle listed in the DID document' do
        json = load_did_json('dholms.json').merge('alsoKnownAs' => ['at://other.example'])

        request = stub_request(:get, "https://plc-mirror.example/#{did}")
          .to_return(body: JSON.generate(json), headers: { 'Content-Type' => 'application/did+json' })

        dns = Resolv::DNS.new(nameserver: '1.1.1.1')

        Resolv::DNS.expects(:new).with(has_entry(:nameserver, '1.1.1.1')).returns(dns)
        dns.expects(:getresources).with('_atproto.dholms.xyz', Resolv::DNS::Resource::IN::TXT)
          .returns([Resolv::DNS::Resource::IN::TXT.new("did=#{did}")])

        result = subject.resolve_handle('dholms.xyz')
        result.should be_nil
        request.should have_been_requested.once
      end
    end

    context 'with verify: false' do
      it 'should accept a resolved DID without checking if it has the handle listed in DID document' do
        dns = Resolv::DNS.new(nameserver: '1.1.1.1')

        Resolv::DNS.expects(:new).with(has_entry(:nameserver, '1.1.1.1')).returns(dns)
        dns.expects(:getresources).with('_atproto.dholms.xyz', Resolv::DNS::Resource::IN::TXT)
          .returns([Resolv::DNS::Resource::IN::TXT.new("did=#{did}")])

        result = subject.resolve_handle('dholms.xyz', verify: false)

        result.should == did
        result.resolved_by.should == :dns
  
        WebMock.should_not have_requested(:get, "https://plc-mirror.example/#{did}")
        WebMock.should_not have_requested(:get, "https://plc.directory/#{did}")
      end      
    end

    it 'should preserve a nil result when the resolver cannot resolve a handle' do
      dns = Resolv::DNS.new(nameserver: '1.1.1.1')

      Resolv::DNS.expects(:new).with(has_entry(:nameserver, '1.1.1.1')).returns(dns)
      dns.expects(:getresources).with('_atproto.dholms.xyz', Resolv::DNS::Resource::IN::TXT).returns([])

      request = stub_request(:get, 'https://dholms.xyz/.well-known/atproto-did').to_return(status: 404)

      result = subject.resolve_handle('dholms.xyz')
      result.should be_nil

      request.should have_been_requested.once
    end

    it 'should use the configured resolver when get_document is called' do
      request = plc_request

      2.times do
        document = did.get_document
        document.did.should == did
        document.pds_endpoint.should == 'https://pds.dholms.xyz'
      end

      request.should have_been_requested.twice
    end

    it 'should use the configured resolver to fetch the document and verify its handle' do
      request = plc_request

      dns = Resolv::DNS.new(nameserver: '1.1.1.1')

      Resolv::DNS.expects(:new).with(has_entry(:nameserver, '1.1.1.1')).returns(dns)
      dns.expects(:getresources).with('_atproto.dholms.xyz', Resolv::DNS::Resource::IN::TXT)
        .returns([Resolv::DNS::Resource::IN::TXT.new("did=#{did}")])

      did.get_verified_handle.should == 'dholms.xyz'

      request.should have_been_requested.once
    end
  end
end
