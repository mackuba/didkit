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
