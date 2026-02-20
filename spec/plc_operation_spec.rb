require 'time'

describe DIDKit::PLCOperation do
  subject { described_class }

  let(:base_json) { load_did_json('bnewbold_log.json').last }

  describe '#initialize' do
    context 'with a valid plc operation' do
      let(:json) { base_json }

      it 'should return a PLCOperation with parsed data' do
        op = subject.new(json)

        op.json.should == json
        op.type.should == :plc_operation
        op.did.should == 'did:plc:44ybard66vv44zksje25o7dz'
        op.cid.should == 'bafyreiaoaelqu32ngmqd2mt3v3zvek7k34cvo7lvmk3kseuuaag5eptg5m'
        op.created_at.should be_a(Time)
        op.created_at.should == Time.parse("2025-06-06T00:34:40.824Z")
        op.handles.should == ['bnewbold.net']
        op.services.map(&:key).should == ['atproto_pds']
      end
    end

    context 'when argument is not a hash' do
      let(:json) { [base_json] }

      it 'should raise a format error' do
        expect { subject.new(json) }.to raise_error(DIDKit::FormatError)
      end
    end

    context 'when did is missing' do
      let(:json) { base_json.tap { |h| h.delete('did') }}

      it 'should raise a format error' do
        expect { subject.new(json) }.to raise_error(DIDKit::FormatError)
      end
    end

    context 'when did is not a string' do
      let(:json) { base_json.merge('did' => 123) }

      it 'should raise a format error' do
        expect { subject.new(json) }.to raise_error(DIDKit::FormatError)
      end
    end

    context "when did doesn't start with did:" do
      let(:json) { base_json.merge('did' => 'foobar') }

      it 'should raise a format error' do
        expect { subject.new(json) }.to raise_error(DIDKit::FormatError)
      end
    end

    context 'when cid is missing' do
      let(:json) { base_json.tap { |h| h.delete('cid') }}

      it 'should raise a format error' do
        expect { subject.new(json) }.to raise_error(DIDKit::FormatError)
      end
    end

    context 'when cid is not a string' do
      let(:json) { base_json.merge('cid' => 700) }

      it 'should raise a format error' do
        expect { subject.new(json) }.to raise_error(DIDKit::FormatError)
      end
    end

    context 'when createdAt is missing' do
      let(:json) { base_json.tap { |h| h.delete('createdAt') }}

      it 'should raise a format error' do
        expect { subject.new(json) }.to raise_error(DIDKit::FormatError)
      end
    end

    context 'when createdAt is invalid' do
      let(:json) { base_json.merge('createdAt' => 123) }

      it 'should raise a format error' do
        expect { subject.new(json) }.to raise_error(DIDKit::FormatError)
      end
    end

    context 'when operation block is missing' do
      let(:json) { base_json.tap { |h| h.delete('operation') }}

      it 'should raise a format error' do
        expect { subject.new(json) }.to raise_error(DIDKit::FormatError)
      end
    end

    context 'when operation block is not a hash' do
      let(:json) { base_json.merge('operation' => 'invalid') }

      it 'should raise a format error' do
        expect { subject.new(json) }.to raise_error(DIDKit::FormatError)
      end
    end

    context 'when operation type is missing' do
      let(:json) { base_json.tap { |h| h['operation'].delete('type') }}

      it 'should raise a format error' do
        expect { subject.new(json) }.to raise_error(DIDKit::FormatError)
      end
    end

    context 'when operation type is not a string' do
      let(:json) { base_json.tap { |h| h['operation']['type'] = 5 }}

      it 'should raise a format error' do
        expect { subject.new(json) }.to raise_error(DIDKit::FormatError)
      end
    end

    context 'when operation type is not plc_operation' do
      let(:json) { base_json.tap { |h| h['operation']['type'] = 'other' }}

      it 'should not raise an error' do
        expect { subject.new(json) }.not_to raise_error
      end

      it 'should return the operation type' do
        op = subject.new(json)
        op.type.should == :other
      end

      it 'should not try to parse services' do
        json['services'] = nil

        expect { subject.new(json) }.not_to raise_error
      end

      it 'should return nil from services' do
        op = subject.new(json)
        op.services.should be_nil
      end

      it 'should not try to parse handles' do
        json['alsoKnownAs'] = nil

        expect { subject.new(json) }.not_to raise_error
      end

      it 'should return nil from handles' do
        op = subject.new(json)
        op.handles.should be_nil
      end
    end

    context 'when alsoKnownAs is not an array' do
      let(:json) { base_json.tap { |h| h['operation']['alsoKnownAs'] = 'at://dholms.xyz' }}

      it 'should raise an AtHandles format error' do
        expect {
          subject.new(json)
        }.to raise_error(DIDKit::FormatError)
      end
    end

    context 'when alsoKnownAs elements are not strings' do
      let(:json) { base_json.tap { |h| h['operation']['alsoKnownAs'] = [666] }}

      it 'should raise an AtHandles format error' do
        expect {
          subject.new(json)
        }.to raise_error(DIDKit::FormatError)
      end
    end

    context 'when alsoKnownAs contains multiple handles' do
      let(:json) {
        base_json.tap { |h|
          h['operation']['alsoKnownAs'] = [
            'at://dholms.xyz',
            'https://example.com',
            'at://other.handle'
          ]
        }
      }

      it 'should pick those starting with at:// and remove the prefixes' do
        op = subject.new(json)
        op.handles.should == ['dholms.xyz', 'other.handle']
      end
    end

    context 'when services are missing' do
      let(:json) { base_json.tap { |h| h['operation'].delete('services') }}

      it 'should raise a format error' do
        expect { subject.new(json) }.to raise_error(DIDKit::FormatError)
      end
    end

    context 'when services entry is not a hash' do
      let(:json) {
        base_json.tap { |h|
          h['operation']['services'] = [
            {
              "id": "#atproto_pds",
              "type": "AtprotoPersonalDataServer",
              "serviceEndpoint": "https://pds.dholms.xyz"
            }
          ]
        }
      }

      it 'should raise a format error' do
        expect { subject.new(json) }.to raise_error(DIDKit::FormatError)
      end
    end

    context 'when a service entry is missing fields' do
      let(:json) {
        base_json.tap { |h|
          h['operation']['services'] = {
            "atproto_pds" => {
              "endpoint" => "https://pds.dholms.xyz"
            },
            "atproto_labeler" => {
              "type" => "AtprotoLabeler",
              "endpoint" => "https://labeler.example.com"
            }
          }
        }
      }

      it 'should raise a format error' do
        expect { subject.new(json) }.to raise_error(DIDKit::FormatError)
      end
    end

    context 'when services are valid' do
      let(:json) {
        base_json.tap { |h|
          h['operation']['services'] = {
            "atproto_pds" => {
              "type" => "AtprotoPersonalDataServer",
              "endpoint" => "https://pds.dholms.xyz"
            },
            "atproto_labeler" => {
              "type" => "AtprotoLabeler",
              "endpoint" => "https://labeler.example.com"
            },
            "custom_service" => {
              "type" => "OtherService",
              "endpoint" => "https://custom.example.com"
            }
          }
        }
      }

      it 'should parse services into ServiceRecords' do
        op = subject.new(json)

        op.services.length.should == 3
        op.services.each { |s| s.should be_a(DIDKit::ServiceRecord) }

        pds, labeller, custom = op.services

        pds.type.should == 'AtprotoPersonalDataServer'
        pds.endpoint.should == 'https://pds.dholms.xyz'

        labeller.type.should == 'AtprotoLabeler'
        labeller.endpoint.should == 'https://labeler.example.com'

        custom.type.should == 'OtherService'
        custom.endpoint.should == 'https://custom.example.com'
      end

      it 'should allow fetching services by key + type' do
        op = subject.new(json)

        custom = op.get_service('custom_service', 'OtherService')
        custom.should be_a(DIDKit::ServiceRecord)
        custom.endpoint.should == 'https://custom.example.com'
      end

      describe '#pds_endpoint' do
        it 'should return the endpoint of #atproto_pds' do
          op = subject.new(json)
          op.pds_endpoint.should == 'https://pds.dholms.xyz'
        end
      end

      describe '#pds_host' do
        it 'should return the host part of #atproto_pds endpoint' do
          op = subject.new(json)
          op.pds_host.should == 'pds.dholms.xyz'
        end
      end

      describe '#labeler_endpoint' do
        it 'should return the endpoint of #atproto_labeler' do
          op = subject.new(json)
          op.labeler_endpoint.should == 'https://labeler.example.com'
        end
      end

      describe '#labeler_host' do
        it 'should return the host part of #atproto_labeler endpoint' do
          op = subject.new(json)
          op.labeler_host.should == 'labeler.example.com'
        end
      end

      it 'should expose the "labeller" aliases for endpoint and host' do
        op = subject.new(json)

        op.labeller_endpoint.should == 'https://labeler.example.com'
        op.labeller_host.should == 'labeler.example.com'
      end
    end

    context 'when services are valid but the specific ones are missing' do
      let(:json) {
        base_json.tap { |h|
          h['operation']['services'] = {
            "custom_service" => {
              "type" => "CustomService",
              "endpoint" => "https://custom.example.com"
            }
          }
        }
      }

      it 'should parse service records' do
        op = subject.new(json)
        op.services.length.should == 1
      end

      describe '#get_service' do
        it 'should return nil' do
          op = subject.new(json)
          other = op.get_service('other_service', 'OtherService')
          other.should be_nil
        end
      end

      describe '#pds_endpoint' do
        it 'should return nil' do
          op = subject.new(json)
          op.pds_endpoint.should be_nil
          op.pds_host.should be_nil
        end
      end

      describe '#labeler_endpoint' do
        it 'should return nil' do
          op = subject.new(json)
          op.labeler_endpoint.should be_nil
          op.labeller_endpoint.should be_nil
          op.labeler_host.should be_nil
          op.labeller_host.should be_nil
        end
      end
    end
  end
end
