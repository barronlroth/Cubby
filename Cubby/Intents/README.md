# Inventory system integration

`InventoryItemEntity` is a custom entity because Apple's schema domains do not
include home inventory. Its query reads accessible saved records through
`SiriInventoryService`; names and home/location subtitles preserve ambiguity
between belongings with the same name.

`LocateInventoryItemIntent` resolves the selected ID again and returns the saved
location as text and spoken dialog. This is deterministic database lookup. It
does not require Foundation Models or infer where an item ought to be stored.
The three app shortcuts support iOS 26. Every action requires the device running
it to be unlocked, and the service must enforce entitlement and home access.

The iOS 27 `.system.open` and `.system.searchInApp` adapters expose supported
navigation schemas. Only `OpenInventoryItemSystemIntent` conforms to `OpenIntent`
for this entity. They are compiled with Xcode 27 / Swift 6.4 and runtime-gated at
iOS 27. The iOS 26 open shortcut is a plain `AppIntent`; system-schema opening
from indexed results is an iOS 27 capability in this implementation.

Indexing and onscreen annotations can help Siri discover this custom entity, but
neither guarantees that Siri AI can answer every free-form inventory question or
follow-up. Verify actual spoken requests on an Apple Intelligence-capable iPhone
with iOS 27. Test intent execution and queries separately from Siri's routing.

App startup must initialize the service before resolving queries, register
`CubbyAppShortcuts.updateAppShortcutParameters()`, and keep Spotlight records
current after mutations, entitlement changes, or shared-home access changes.
Entity export is a plain-text summary only; receiving text never creates items.

References:

- [Custom entities](https://developer.apple.com/documentation/appintents/defining-app-entities-for-your-custom-data-types)
- [System schemas](https://developer.apple.com/documentation/appintents/app-schema-domain-system-and-in-app-search)
- [Search schema](https://developer.apple.com/documentation/appintents/appschema/systemintent/searchinapp)
- [Open schema](https://developer.apple.com/documentation/appintents/appschema/systemintent/open)
- [Authentication](https://developer.apple.com/documentation/appintents/intentauthenticationpolicy)
- [Testing the integration](https://developer.apple.com/documentation/appintentstesting/testing-your-app-intents-code)
