## [0.3.0] - 2025-12-15

Breaking changes:

* removed `DID#is_known_by_relay?` – it doesn't work anymore, since relays are now non-archival and they expose almost no XRPC routes
* renamed a few handle-related methods:
  - `get_validated_handle` -> `get_verified_handle`
  - `pick_valid_handle` -> `first_verified_handle`

Also:

- added `DID#account_status` method, which checks `getRepoStatus` endpoint to tell if an account is active, deactivated, taken down etc.
- added `DID#account_active?` helper (`account_status == :active`)
- `DID#account_exists?` now calls `getRepoStatus` (via `account_status`, checking if it's not nil) instead of `getLatestCommit`
- added `DID#document` which keeps a memoized copy of the document
- added `pds_host` & `labeler_host` methods to `PLCOperation` and `Document`, which return the PDS/labeller address without the `https://`
- added `labeller_endpoint` & `labeller_host` aliases for the double-L enjoyers :]
- added `PLCOperation#cid`
- `PLCImporter` now removes duplicate operations at the edge of pages returned from the `/export` API
- rewritten some networking code – all classes now use `Net::HTTP` with consistent options instead of `open-uri`

Note: `PLCImporter` will be rewritten soon to add support for updated [plc.directory](https://plc.directory) APIs, so be prepared for some breaking changes there in v. 0.4.

## [0.2.3] - 2024-07-02

- added a `DID#get_audit_log` method that fetches the PLC audit log for a DID
- added a way to set an error handler in `PLCImporter`
- reverted the change from 0.2.1 that added Ruby stdlib dependencies explicitly to the gemspec, since this causes more problems than it's worth
- minor bug fixes

## [0.2.2] - 2024-04-01

- added helpers for checking if a DID is known by (federated with) a relay or if the repo exists on its assigned PDS

## [0.2.1] - 2024-03-26

- tweaked validations in `Document` and `PLCOperation` to make them more aligned with what might be expected
- added Ruby stdlib dependencies explicitly to the gemspec

## [0.2.0] - 2024-03-19

- added `PLCImporter` class, which lets you import operations from PLC in pages of 1000 through the "export" API
- implemented parsing of all services from DID doc & operations, not only `atproto_pds` (specifically labeller endpoints)
- allow setting the nameserver in `Resolver` initializer

## [0.1.0] - 2024-03-12

- rejecting handles from disallowed domains like `.arpa` or `.test`
- validating handles with the `.well-known` file having a trailing newline
- validating handles with `.well-known` address returning a redirect
- added `#pick_valid_handle` helper
- allow overriding the nameserver for `Resolv::DNS`
- other bug fixes

## [0.0.4] - 2024-03-07

- extracted resolving code from `DID` to a new `Resolver` class (`DID` has helper methods to call the resolver)
- added `Resolver#get_validated_handle` method to validate handles from the `Document` (+ helpers in `DID` in `Document`)
- added timeout to `#resolve_handle_by_well_known`

## [0.0.3] - 2024-03-06

- added `Document#handles` with handle info extracted from `alsoKnownAs` field
- added validation of various fields of the DID document
- added `DID#resolved_by` (`:dns` or `:http`)
- added `DID#did` which returns the DID in a string form like `to_s`
- added `DID#web_domain` which returns the domain part of a `did:web`
- changed `DID#type` to be stored as a symbol

## [0.0.2] - 2023-11-14

- fixed missing require
- fixed some connection error handling

## [0.0.1] - 2023-11-14

Initial release:

- resolving handle to DID via DNS or HTTP well-known
- loading DID document via PLC or did:web well-known
- extracting PDS endpoint field from the DID doc
