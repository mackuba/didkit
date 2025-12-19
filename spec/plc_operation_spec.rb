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
        expect { subject.new(json) }.to raise_error(DIDKit::PLCOperation::FormatError)
      end
    end

    context 'when did is missing' do
      let(:json) { base_json.tap { |h| h.delete('did') }}

      it 'should raise a format error' do
        expect { subject.new(json) }.to raise_error(DIDKit::PLCOperation::FormatError)
      end
    end

    context 'when did is not a string' do
      let(:json) { base_json.merge('did' => 123) }

      it 'should raise a format error' do
        expect { subject.new(json) }.to raise_error(DIDKit::PLCOperation::FormatError)
      end
    end

    context "when did doesn't start with did:" do
      let(:json) { base_json.merge('did' => 'foobar') }

      it 'should raise a format error' do
        expect { subject.new(json) }.to raise_error(DIDKit::PLCOperation::FormatError)
      end
    end

    context 'when cid is missing' do
      let(:json) { base_json.tap { |h| h.delete('cid') }}

      it 'should raise a format error' do
        expect { subject.new(json) }.to raise_error(DIDKit::PLCOperation::FormatError)
      end
    end

    context 'when cid is not a string' do
      let(:json) { base_json.merge('cid' => 700) }

      it 'should raise a format error' do
        expect { subject.new(json) }.to raise_error(DIDKit::PLCOperation::FormatError)
      end
    end

    context 'when createdAt is missing' do
      let(:json) { base_json.tap { |h| h.delete('createdAt') }}

      it 'should raise a format error' do
        expect { subject.new(json) }.to raise_error(DIDKit::PLCOperation::FormatError)
      end
    end

    context 'when createdAt is invalid' do
      let(:json) { base_json.merge('createdAt' => 123) }

      it 'should raise a format error' do
        expect { subject.new(json) }.to raise_error(DIDKit::PLCOperation::FormatError)
      end
    end

    context 'when operation block is missing' do
      let(:json) { base_json.tap { |h| h.delete('operation') }}

      it 'should raise a format error' do
        expect { subject.new(json) }.to raise_error(DIDKit::PLCOperation::FormatError)
      end
    end

    context 'when operation block is not a hash' do
      let(:json) { base_json.merge('operation' => 'invalid') }

      it 'should raise a format error' do
        expect { subject.new(json) }.to raise_error(DIDKit::PLCOperation::FormatError)
      end
    end

    context 'when operation type is missing' do
      let(:json) { base_json.tap { |h| h['operation'].delete('type') }}

      it 'should raise a format error' do
        expect { subject.new(json) }.to raise_error(DIDKit::PLCOperation::FormatError)
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
        }.to raise_error(DIDKit::AtHandles::FormatError)
      end
    end

    context 'when alsoKnownAs elements are not strings' do
      let(:json) { base_json.tap { |h| h['operation']['alsoKnownAs'] = [666] }}

      it 'should raise an AtHandles format error' do
        expect {
          subject.new(json)
        }.to raise_error(DIDKit::AtHandles::FormatError)
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
        expect { subject.new(json) }.to raise_error(DIDKit::PLCOperation::FormatError)
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
        expect { subject.new(json) }.to raise_error(DIDKit::PLCOperation::FormatError)
      end
    end
  end
end
