describe DIDKit::Requests do
  class RequestsTest
    include DIDKit::Requests
  end

  subject { RequestsTest.new }

  describe 'redirects' do
    it 'should reject a redirect from HTTPS to HTTP without requesting the target' do
      stub_request(:get, 'https://plc.directory/start')
        .to_return(status: 302, headers: { 'Location' => 'http://localhost/target' })

      target = stub_request(:get, 'http://localhost/target').to_return(body: 'insecure')

      expect { subject.send(:get_data, 'https://plc.directory/start') }
        .to raise_error(DIDKit::APIError) { |error| error.status.should == 302 }

      expect(target).not_to have_been_requested
    end

    it 'should reject a downgrade after an HTTP request has redirected to HTTPS' do
      stub_request(:get, 'http://localhost/start')
        .to_return(status: 302, headers: { 'Location' => 'https://plc.directory/secure' })
      stub_request(:get, 'https://plc.directory/secure')
        .to_return(status: 307, headers: { 'Location' => 'http://localhost/target' })

      target = stub_request(:get, 'http://localhost/target').to_return(body: 'insecure')

      expect { subject.send(:get_data, 'http://localhost/start') }
        .to raise_error(DIDKit::APIError) { |error| error.status.should == 307 }

      expect(target).not_to have_been_requested
    end

    [
      ['https://plc.directory/start', 'https://plc.directory/target'],
      ['https://plc.directory/start', '/target'],
      ['http://localhost/start', 'http://localhost/target'],
      ['http://localhost/start', 'https://plc.directory/target']
    ].each do |source, location|
      it "should follow a redirect from #{source} to #{location}" do
        target = location.start_with?('/') ? 'https://plc.directory/target' : location
        stub_request(:get, source).to_return(status: 302, headers: { 'Location' => location })

        request = stub_request(:get, target).to_return(body: 'resolved')

        response = subject.send(:get_data, source)
        response.should == 'resolved'

        expect(request).to have_been_requested.once
      end
    end
  end
end
