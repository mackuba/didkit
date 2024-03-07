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
