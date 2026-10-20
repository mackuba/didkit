describe DIDKit::Services do
  [:document, :operation].each do |source|
    context "with services from a #{source}" do
      let(:endpoint) { 'https://service.example' }

      subject do
        if source == :document
          did = DIDKit::DID.new('did:plc:yk4dd2qkboz2yv6tpubpc6co')
          json = load_did_json('dholms.json').merge('service' => [
            { 'id' => '#atproto_pds', 'type' => 'AtprotoPersonalDataServer', 'serviceEndpoint' => endpoint },
            { 'id' => '#atproto_labeler', 'type' => 'AtprotoLabeler', 'serviceEndpoint' => endpoint },
            { 'id' => '#custom', 'type' => 'CustomService', 'serviceEndpoint' => endpoint }
          ])
          DIDKit::Document.new(did, json)
        else
          json = load_did_json('bnewbold_log.json').last
          json['operation']['services'] = {
            'atproto_pds' => { 'type' => 'AtprotoPersonalDataServer', 'endpoint' => endpoint },
            'atproto_labeler' => { 'type' => 'AtprotoLabeler', 'endpoint' => endpoint },
            'custom' => { 'type' => 'CustomService', 'endpoint' => endpoint }
          }
          DIDKit::PLCOperation.new(json)
        end
      end

      ['https://service.example', 'http://onet.pl', 'http://localhost:3000', 'https://app.example:999'].each do |url|
        context "with endpoint #{url}" do
          let(:endpoint) { url }

          it 'should accept the endpoint for PDS' do
            subject.pds_endpoint.should == endpoint
            subject.pds_host.should == URI(endpoint).host
          end
        end
      end

      [
        'ftp://service.example', 'mailto:admin@example.com', '/relative',
        'https://', 'https:opaque', 'https:///path',
        'https://service.example/', 'https://service.example/path',
        'https://user:password@service.example',
        'https://service.example?query=value', 'https://service.example#fragment',
        'https://service.example?', 'https://service.example#'
      ].each do |url|
        context "with endpoint #{url}" do
          let(:endpoint) { url }

          it 'should reject the PDS endpoint without discarding the raw service record' do
            subject.pds_endpoint.should be_nil
            subject.pds_host.should be_nil

            subject.get_service('atproto_pds', 'AtprotoPersonalDataServer').endpoint.should == endpoint
            subject.get_service('custom', 'CustomService').endpoint.should == endpoint
          end
        end
      end

      [
        'https://service.example', 'http://localhost:3000',
        'https://service.example/', 'https://service.example/path',
        'https://user:password@service.example:8443/path?query=value#fragment'
      ].each do |url|
        context "with endpoint #{url}" do
          let(:endpoint) { url }

          it 'should accept the endpoint for labeller' do
            subject.labeler_endpoint.should == endpoint
            subject.labeller_endpoint.should == endpoint

            subject.labeler_host.should == URI(endpoint).host
            subject.labeller_host.should == URI(endpoint).host
          end
        end
      end

      [
        'ftp://service.example', 'mailto:admin@example.com',
        '/relative', 'https://', 'https:opaque', 'https:///path'
      ].each do |url|
        context "with endpoint #{url}" do
          let(:endpoint) { url }

          it 'should reject the endpoint for labeller without discarding the raw service record' do
            subject.labeler_endpoint.should be_nil
            subject.labeller_endpoint.should be_nil
            subject.labeler_host.should be_nil
            subject.labeller_host.should be_nil

            subject.get_service('atproto_labeler', 'AtprotoLabeler').endpoint.should == endpoint
            subject.get_service('custom', 'CustomService').endpoint.should == endpoint
          end
        end
      end
    end
  end
end
