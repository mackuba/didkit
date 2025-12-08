# DIDKit 🪪

A small Ruby gem for handling Distributed Identifiers (DIDs) in Bluesky / AT Protocol.

> [!NOTE]
> Part of ATProto Ruby SDK: [ruby.sdk.blue](https://ruby.sdk.blue)


## What does it do

Accounts on Bluesky use identifiers like [did:plc:oio4hkxaop4ao4wz2pp3f4cr](https://plc.directory/did:plc:oio4hkxaop4ao4wz2pp3f4cr) as unique IDs, and they also have assigned human-readable handles like [@mackuba.eu](https://bsky.app/profile/mackuba.eu), which are verified either through a DNS TXT entry or a `/.well-known/atproto-did` file. This library allows you to look up any account's assigned handle using a DID string or vice versa, load the account's DID JSON document that specifies the handles and the PDS server hosting user's repo, and check if the assigned handle verifies correctly.


## Installation

    gem install didkit


## Usage

Use the `DIDKit::Resolver` class to look up DIDs and handles.

To look up a handle:

```rb
resolver = DIDKit::Resolver.new
resolver.resolve_handle('nytimes.com')
 # => #<DIDKit::DID:0x00000001035956b0 @did="did:plc:eclio37ymobqex2ncko63h4r", @type=:plc, @resolved_by=:dns>
```

This returns an object of `DIDKit::DID` class (aliased as just `DID`), which tells you:

- the DID as a string (`#to_s` or `#did`)
- the DID type (`#type`, `:plc` or `:web`)
- if the handle was resolved via a DNS entry or a `.well-known` file (`#resolved_by`, `:dns` or `:http`)

To go in the other direction – to find an assigned and verified handle given a DID – use `get_validated_handle` (pass DID as a string or an object):

```rb
resolver.get_validated_handle('did:plc:ewvi7nxzyoun6zhxrhs64oiz')
 # => "atproto.com" 
```

You can also load the DID document using `resolve_did`:

```rb
doc = resolver.resolve_did('did:plc:ragtjsm2j2vknwkz3zp4oxrd')
 # => #<DIDKit::Document:0x0000000105d751f8 @did=#<DIDKit::DID:...>, @json={...}>

doc.handles
 # => ["pfrazee.com"] 

doc.pds_endpoint
 # => "https://morel.us-east.host.bsky.network" 
```

There are also some helper methods in the `DID` class that create a `Resolver` for you to save you some typing:

```rb
did = DID.resolve_handle('jay.bsky.team')
 #  => #<DIDKit::DID:0x000000010615ed28 @did="did:plc:oky5czdrnfjpqslsw2a5iclo", @type=:plc, @resolved_by=:dns>

did.to_s
 # => "did:plc:oky5czdrnfjpqslsw2a5iclo" 

did.get_document
 # => #<DIDKit::Document:0x00000001066d4898 @did=#<DIDKit::DID:...>, @json={...}>

did.get_validated_handle
 # => "jay.bsky.team" 
```


### Configuration

You can override the nameserver used for DNS lookups by setting the `nameserver` property in `Resolver`, e.g. to use Google's or CloudFlare's global DNS:

```
resolver.nameserver = '8.8.8.8'
```


## Credits

Copyright © 2025 Kuba Suder ([@mackuba.eu](https://bsky.app/profile/did:plc:oio4hkxaop4ao4wz2pp3f4cr)).

The code is available under the terms of the [zlib license](https://choosealicense.com/licenses/zlib/) (permissive, similar to MIT).
