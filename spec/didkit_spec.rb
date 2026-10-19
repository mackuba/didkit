# frozen_string_literal: true

RSpec.describe DIDKit do
  it "has a version number" do
    expect(DIDKit::VERSION).not_to be nil
  end

  describe '.default_resolver' do
    before do
      @shared_resolver = DIDKit.default_resolver
    end

    it 'should return a shared Resolver instance' do
      resolver = DIDKit.default_resolver

      resolver.should be_a(DIDKit::Resolver)
      DIDKit.default_resolver.should equal(resolver)
    end

    it 'should allow overriding the shared Resolver instance' do
      cloudflare_resolver = DIDKit::Resolver.new(nameserver: '1.1.1.1')
      DIDKit.default_resolver = cloudflare_resolver

      DIDKit.default_resolver.should equal(cloudflare_resolver)
    end

    after do
      DIDKit.default_resolver = @shared_resolver
    end
  end
end
