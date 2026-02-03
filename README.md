# DIDKit 🪪

A small Ruby gem for handling Distributed Identifiers (DIDs) in Bluesky / AT Protocol.

> [!NOTE]
> Part of ATProto Ruby SDK: [ruby.sdk.blue](https://ruby.sdk.blue)


## What does it do

Accounts on Bluesky use identifiers like [did:plc:oio4hkxaop4ao4wz2pp3f4cr](https://plc.directory/did:plc:oio4hkxaop4ao4wz2pp3f4cr) as unique IDs, and they also have assigned human-readable handles like [@mackuba.eu](https://bsky.app/profile/mackuba.eu), which are verified either through a DNS TXT entry or a `/.well-known/atproto-did` file. This library allows you to look up any account's assigned handle using a DID string or vice versa, load the account's DID JSON document that specifies the handles and the PDS server hosting user's repo, and check if the assigned handle verifies correctly.


## Installation

To use DIDKit, you need a reasonably new version of Ruby – it should run on Ruby 2.6 and above, although it's recommended to use a version that's still getting maintainance updates, i.e. currently 3.2+. A compatible version should be preinstalled on macOS Big Sur and above and on many Linux systems. Otherwise, you can install one using tools such as [RVM](https://rvm.io), [asdf](https://asdf-vm.com), [ruby-install](https://github.com/postmodern/ruby-install) or [ruby-build](https://github.com/rbenv/ruby-build), or `rpm` or `apt-get` on Linux (see more installation options on [ruby-lang.org](https://www.ruby-lang.org/en/downloads/)).

To install the gem, run in the command line:

    [sudo] gem install didkit

Or add this to your app's `Gemfile`:

    gem 'didkit', '~> 0.3'


## Usage

The simplest way to use the gem is through the `DIDKit::DID` class, aliased as just `DID`:

```rb
did = DID.resolve_handle('jay.bsky.team')
  # => #<DIDKit::DID:0x0... @did="did:plc:oky5czdrnfjpqslsw2a5iclo",
  #       @resolved_by=:dns, @type=:plc>
```

This returns a `DID` object, which tells you:

- the DID as a string (`#to_s` or `#did`)
- the DID type (`#type`, `:plc` or `:web`)
- if the handle was resolved via a DNS entry or a `.well-known` file (`#resolved_by`, `:dns` or `:http`)

To go in the other direction – to find an assigned and verified handle given a DID – create a `DID` from a DID string and call `get_verified_handle`:

```rb
DID.new('did:plc:ewvi7nxzyoun6zhxrhs64oiz').get_verified_handle
  # => "atproto.com"
```

You can also load the DID JSON document using `#document`, which returns a `DIDKit::Document` (`DID` caches the document, so don't worry about calling this method multiple times):

```rb
did = DID.new('did:plc:ragtjsm2j2vknwkz3zp4oxrd')

did.document.handles
  # => ["pfrazee.com"]

did.document.pds_host
  # => "morel.us-east.host.bsky.network"
```


### Checking account status

`DIDKit::DID` also includes a few methods for checking the status of a given account (repo), which call the `com.atproto.sync.getRepoStatus` endpoint on the account's assigned PDS:

```rb
did = DID.new('did:plc:ch7azdejgddtlijyzurfdihn')
did.account_status
  # => :takendown
did.account_active?
  # => false
did.account_exists?
  # => true

did = DID.new('did:plc:44ybard66vv44zksje25o7dz')
did.account_status
  # => :active
did.account_active?
  # => true
```

### Configuration

You can customize some things about the DID/handle lookups by using the `DIDKit::Resolver` class, which the methods in `DID` use behind the scenes.

Currently available options include:

- `:nameserver` - override the nameserver used for DNS lookups, e.g. to use Google's or CloudFlare's DNS
- `:timeout` - change the connection/response timeout for HTTP requests (default: 15 s)
- `:max_redirects` - change allowed maximum number of redirects (default: 5)

Example:

```rb
resolver = DIDKit::Resolver.new(nameserver: '8.8.8.8', timeout: 30)

did = resolver.resolve_handle('nytimes.com')
  # => #<DIDKit::DID:0x0... @did="did:plc:eclio37ymobqex2ncko63h4r",
  #       @resolved_by=:dns, @type=:plc>

resolver.resolve_did(did)
  # => #<DIDKit::Document:0x0... @did=#<DIDKit::DID:...>, @json={...}>

resolver.get_verified_handle(did)
  # => 'nytimes.com'
```

## Credits

Copyright © 2026 Kuba Suder ([@mackuba.eu](https://bsky.app/profile/did:plc:oio4hkxaop4ao4wz2pp3f4cr)).

The code is available under the terms of the [zlib license](https://choosealicense.com/licenses/zlib/) (permissive, similar to MIT).

Bug reports and pull requests are welcome 😎
