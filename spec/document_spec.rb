describe DIDKit::Document do
  subject { described_class }

  let(:did) { DID.new('did:plc:yk4dd2qkboz2yv6tpubpc6co') }
  let(:base_json) { load_did_json('dholms.json') }

  describe '#initialize' do
    context 'with valid input' do
      let(:json) { base_json }

      it 'should return a Document object' do
        doc = subject.new(did, json)

        doc.should be_a(DIDKit::Document)
        doc.did.should == did
        doc.json.should == json
      end

      it 'should parse services from the JSON' do
        doc = subject.new(did, json)

        doc.services.should be_an(Array)
        doc.services.length.should == 1

        doc.services[0].should be_a(DIDKit::ServiceRecord)
        doc.services[0].key.should == 'atproto_pds'
        doc.services[0].type.should == 'AtprotoPersonalDataServer'
        doc.services[0].endpoint.should == 'https://pds.dholms.xyz'
      end

      it 'should parse handles from the JSON' do
        doc = subject.new(did, json)

        doc.handles.should == ['dholms.xyz']
      end
    end

    context 'when id is missing' do
      let(:json) { base_json.dup.tap { |h| h.delete('id') }}

      it 'should raise a format error' do
        expect {
          subject.new(did, json)
        }.to raise_error(DIDKit::FormatError)
      end
    end

    context 'when id is not a string' do
      let(:json) { base_json.merge('id' => 123) }

      it 'should raise a format error' do
        expect {
          subject.new(did, json)
        }.to raise_error(DIDKit::FormatError)
      end
    end

    context 'when id does not match the DID' do
      let(:json) { base_json.merge('id' => 'did:plc:notmatching') }

      it 'should raise a format error' do
        expect {
          subject.new(did, json)
        }.to raise_error(DIDKit::FormatError)
      end
    end

    context 'when alsoKnownAs is not an array' do
      let(:json) { base_json.merge('alsoKnownAs' => 'at://dholms.xyz') }

      it 'should raise an AtHandles format error' do
        expect {
          subject.new(did, json)
        }.to raise_error(DIDKit::FormatError)
      end
    end

    context 'when alsoKnownAs elements are not strings' do
      let(:json) { base_json.merge('alsoKnownAs' => [666]) }

      it 'should raise an AtHandles format error' do
        expect {
          subject.new(did, json)
        }.to raise_error(DIDKit::FormatError)
      end
    end

    context 'when alsoKnownAs contains multiple handles' do
      let(:json) {
        base_json.merge('alsoKnownAs' => [
          'at://dholms.xyz',
          'https://example.com',
          'at://other.handle'
        ])
      }

      it 'should pick those starting with at:// and remove the prefixes' do
        doc = subject.new(did, json)
        doc.handles.should == ['dholms.xyz', 'other.handle']
      end
    end

    context 'when service is not an array' do
      let(:json) { base_json.merge('service' => 'not-an-array') }

      it 'should raise a format error' do
        expect {
          subject.new(did, json)
        }.to raise_error(DIDKit::FormatError)
      end
    end

    context 'when service entries are not hashes' do
      let(:json) { base_json.merge('service' => ['invalid']) }

      it 'should raise a format error' do
        expect {
          subject.new(did, json)
        }.to raise_error(DIDKit::FormatError)
      end
    end

    context 'when service entries are partially valid' do
      let(:services) {
        [
          { 'id' => '#atproto_pds', 'type' => 'AtprotoPersonalDataServer', 'serviceEndpoint' => 'https://pds.dholms.xyz' },
          { 'id' => 'not_a_hash', 'type' => 'AtprotoPersonalDataServer', 'serviceEndpoint' => 'https://pds.dholms.xyz' },
          { 'id' => '#wrong_type', 'type' => 123, 'serviceEndpoint' => 'https://pds.dholms.xyz' },
          { 'id' => '#wrong_endpoint', 'type' => 'AtprotoPersonalDataServer', 'serviceEndpoint' => 123 },
          { 'id' => '#lycan', 'type' => 'LycanService', 'serviceEndpoint' => 'https://lycan.feeds.blue' }
        ]
      }

      let(:json) { base_json.merge('service' => services) }

      it 'should only keep the valid records' do
        doc = subject.new(did, json)

        doc.services.length.should == 2
        doc.services.map(&:key).should == ['atproto_pds', 'lycan']
        doc.services.map(&:type).should == ['AtprotoPersonalDataServer', 'LycanService']
        doc.services.map(&:endpoint).should == ['https://pds.dholms.xyz', 'https://lycan.feeds.blue']
      end
    end
  end

  describe 'service helpers' do
    let(:service_json) {
      base_json.merge('service' => [
        { 'id' => '#atproto_pds', 'type' => 'AtprotoPersonalDataServer', 'serviceEndpoint' => 'https://pds.dholms.xyz' },
        { 'id' => '#atproto_labeler', 'type' => 'AtprotoLabeler', 'serviceEndpoint' => 'https://labels.dholms.xyz' },
        { 'id' => '#lycan', 'type' => 'LycanService', 'serviceEndpoint' => 'https://lycan.feeds.blue' }
      ])
    }

    describe '#pds_endpoint' do
      it 'should return the endpoint of #atproto_pds' do
        doc = subject.new(did, service_json)
        doc.pds_endpoint.should == 'https://pds.dholms.xyz'
      end
    end

    describe '#pds_host' do
      it 'should return the host part of #atproto_pds endpoint' do
        doc = subject.new(did, service_json)
        doc.pds_host.should == 'pds.dholms.xyz'
      end
    end

    describe '#labeler_endpoint' do
      it 'should return the endpoint of #atproto_labeler' do
        doc = subject.new(did, service_json)
        doc.labeler_endpoint.should == 'https://labels.dholms.xyz'
      end
    end

    describe '#labeler_host' do
      it 'should return the host part of #atproto_labeler endpoint' do
        doc = subject.new(did, service_json)
        doc.labeler_host.should == 'labels.dholms.xyz'
      end
    end

    describe '#get_service' do
      it 'should fetch a service by key and type' do
        doc = subject.new(did, service_json)

        lycan = doc.get_service('lycan', 'LycanService')
        lycan.should_not be_nil
        lycan.endpoint.should == 'https://lycan.feeds.blue'
      end

      it 'should return nil if none of the services match' do
        doc = subject.new(did, service_json)

        result = doc.get_service('lycan', 'AtprotoLabeler')
        result.should be_nil

        result = doc.get_service('atproto_pds', 'PDS')
        result.should be_nil

        result = doc.get_service('unknown', 'Test')
        result.should be_nil
      end
    end

    it 'should expose the "labeller" aliases for endpoint and host' do
      doc = subject.new(did, service_json)

      doc.labeller_endpoint.should == 'https://labels.dholms.xyz'
      doc.labeller_host.should == 'labels.dholms.xyz'
    end

    describe 'if there is no matching service' do
      let(:service_json) {
        base_json.merge('service' => [
          { 'id' => '#lycan', 'type' => 'LycanService', 'serviceEndpoint' => 'https://lycan.feeds.blue' }
        ])
      }

      it 'should return nil from the relevant methods' do
        doc = subject.new(did, service_json)

        doc.pds_endpoint.should be_nil
        doc.pds_host.should be_nil
        doc.labeller_endpoint.should be_nil
        doc.labeller_host.should be_nil
        doc.labeler_endpoint.should be_nil
        doc.labeler_host.should be_nil
      end
    end
  end
end
