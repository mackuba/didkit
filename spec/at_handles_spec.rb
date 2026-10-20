describe DIDKit::AtHandles do
  [:document, :operation].each do |source|
    context "when parsing a #{source}" do
      let(:aliases) {
        [
          'https://example.com', 'at://bad_handle', 'at://example.com?query',
          'at://example.com#fragment', 'at://example.com:443',
          'at://example.com/path', 'at://example.com/', 'at://',
          'at://at://example.com', 'at://example..com', 'at://bücher.de',
          'at://dholms.xyz', 'at://other.handle', 'at://something',
          'at://myapp.3com', 'at://-google.com', 'at://server-.com',
          'at://localhost', 'at://localhost:3000'
        ]
      }

      subject do
        if source == :document
          did = DIDKit::DID.new('did:plc:yk4dd2qkboz2yv6tpubpc6co')
          json = load_did_json('dholms.json').merge('alsoKnownAs' => aliases)
          DIDKit::Document.new(did, json)
        else
          json = load_did_json('bnewbold_log.json').last
          json['operation']['alsoKnownAs'] = aliases
          DIDKit::PLCOperation.new(json)
        end
      end

      it 'should exclude invalid handle URIs and preserve valid handle order' do
        subject.handles.should == ['dholms.xyz', 'other.handle']
      end

      it 'should preserve all original alsoKnownAs entries' do
        subject.also_known_as.should == aliases
      end

      context 'with repeated at:// prefix' do
        let(:aliases) { ['at://foo.at://example.com'] }

        it 'should reject the entry instead of turning it into a valid-looking handle' do
          subject.handles.should == []
          subject.also_known_as.should == ['at://foo.at://example.com']
        end
      end

      context 'with handles at the length boundary' do
        let(:valid_handle) { (['a' * 63] * 3 + ['b' * 61]).join('.') }
        let(:aliases) { ["at://#{valid_handle}b", "at://#{valid_handle}"] }

        it 'should accept a 253-character handle and exclude a 254-character handle' do
          valid_handle.length.should == 253
          subject.handles.should == [valid_handle]
        end
      end

      context 'with a reserved top-level domain' do
        let(:aliases) { ['at://example.test', 'at://dholms.xyz'] }

        it 'should include them on the handles list as syntactically valid' do
          subject.handles.should == ['example.test', 'dholms.xyz']
        end
      end
    end
  end
end
