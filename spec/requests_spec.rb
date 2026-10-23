describe DIDKit::Requests do
  class RequestsTest
    include DIDKit::Requests
  end

  subject { RequestsTest.new }

  describe 'timeouts' do
    let(:success) { Net::HTTPOK.new('1.1', '200', 'OK') }

    let(:redirect) do
      Net::HTTPFound.new('1.1', '302', 'Found').tap { |response| response['Location'] = '/target' }
    end

    let(:http) { mock('HTTP connection') }

    before do
      http.expects(:request).with(is_a(Net::HTTP::Get)).twice.returns(redirect, success)
    end

    def expect_http_timeouts(timeout)
      Net::HTTP.expects(:start).with(
        'plc.directory', 443, { open_timeout: timeout, read_timeout: timeout, use_ssl: true }
      ).twice.yields(http).returns(redirect, success)
    end

    it 'should pass timeout option as open and read timeouts to Net::HTTP' do
      expect_http_timeouts(2)

      subject.send(:get_response, 'https://plc.directory/start', timeout: 2).should equal(success)
    end

    it 'should use a default timeout of 15 seconds' do
      expect_http_timeouts(15)

      subject.send(:get_response, 'https://plc.directory/start').should equal(success)
    end
  end

  describe 'redirects' do
    def expect_redirect_limit(limit, with_options:)
      requests = (0..limit + 1).map do |hop|
        stub_request(:get, "https://plc.directory/hop-#{hop}")
          .to_return(status: 302, headers: { 'Location' => "/hop-#{hop + 1}" })
      end

      expect { subject.send(:get_data, 'https://plc.directory/hop-0', with_options) }
        .to raise_error(DIDKit::APIError) { |error| error.status.should == 302 }

      requests[0..limit].each { |request| request.should have_been_requested.once }
      requests.last.should_not have_been_requested
    end

    it 'should stop after a configured maximum number of redirects' do
      expect_redirect_limit(2, with_options: { max_redirects: 2 })
    end

    it 'should allow up to 5 redirects by default' do
      expect_redirect_limit(5, with_options: {})
    end

    it 'should accept success after exactly the allowed number of redirects' do
      stub_request(:get, 'https://plc.directory/start')
        .to_return(status: 302, headers: { 'Location' => '/middle' })
      stub_request(:get, 'https://plc.directory/middle')
        .to_return(status: 302, headers: { 'Location' => '/target' })

      target = stub_request(:get, 'https://plc.directory/target').to_return(body: 'resolved')

      subject.send(:get_data, 'https://plc.directory/start', max_redirects: 2).should == 'resolved'

      target.should have_been_requested.once
    end

    it "should reject redirects non-HTTP URLs" do
      ['https://plc.directory/start', 'http://localhost/start'].each do |source|
        [
          'ftp://files.example/target',
          'file:///tmp/target',
          'ws://files.example/target',
          'mailto:admin@example.com',
          'data:text/plain,target',
          'javascript:alert(1)'
        ].each do |location|
          stub_request(:get, source).to_return(status: 302, headers: { 'Location' => location })

          expect { subject.send(:get_data, source) }.to raise_error(DIDKit::APIError) { |error| error.status.should == 302 }

          WebMock.should_not have_requested(:any, /.*/).with { |req| req.uri != Addressable::URI.parse(source) }
          WebMock.reset!
        end
      end
    end

    it 'should reject a redirect from HTTPS to HTTP without requesting the target' do
      stub_request(:get, 'https://plc.directory/start')
        .to_return(status: 302, headers: { 'Location' => 'http://localhost/target' })

      target = stub_request(:get, 'http://localhost/target').to_return(body: 'insecure')

      expect { subject.send(:get_data, 'https://plc.directory/start') }
        .to raise_error(DIDKit::APIError) { |error| error.status.should == 302 }

      target.should_not have_been_requested
    end

    it 'should reject a downgrade after an HTTP request has redirected to HTTPS' do
      stub_request(:get, 'http://localhost/start')
        .to_return(status: 302, headers: { 'Location' => 'https://plc.directory/secure' })
      stub_request(:get, 'https://plc.directory/secure')
        .to_return(status: 307, headers: { 'Location' => 'http://localhost/target' })

      target = stub_request(:get, 'http://localhost/target').to_return(body: 'insecure')

      expect { subject.send(:get_data, 'http://localhost/start') }
        .to raise_error(DIDKit::APIError) { |error| error.status.should == 307 }

      target.should_not have_been_requested
    end

    [
      ['https://plc.directory/start',      'https://plc.directory/target', 'https://plc.directory/target'],
      ['https://plc.directory/start',      '/target',                      'https://plc.directory/target'],
      ['https://plc.directory/path/start', '../target',                    'https://plc.directory/target'],
      ['https://plc.directory/start',      '//mirror.example/target',      'https://mirror.example/target'],
      ['http://localhost/start',           'http://localhost/target',      'http://localhost/target'],
      ['http://localhost/start',           'http://other',                 'http://other'],
      ['http://localhost/start',           'https://plc.directory/target', 'https://plc.directory/target']
    ].each do |source, location, target|
      it "should follow a redirect from #{source} to #{location}" do
        stub_request(:get, source).to_return(status: 302, headers: { 'Location' => location })

        request = stub_request(:get, target).to_return(body: 'resolved')

        response = subject.send(:get_data, source)
        response.should == 'resolved'

        request.should have_been_requested.once
      end
    end
  end
end
