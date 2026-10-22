# CarPlay

Native audio-category templates: Queue, Downloads, Favorites and Recently Played,
with Apple's shared Now Playing screen. The car and phone use the same player,
queue transactions and one headless-capable Flutter engine, including car-only
cold launch. Lists are bounded to 100 rows. Playback/library listeners and refresh timers
exist only while connected; disconnected commands are rejected. A late startup
handshake cannot overwrite a newer connection event.
Selecting a library song queues its collection; queue selections retain the queue.
Stale rows are revalidated against the live catalog. Setup and Sing stay on phone.

## Signing

Runner declares `com.apple.developer.carplay-audio` in `Runner.entitlements`.
Apple must approve the capability for the App ID and the signing provisioning
profile must contain it. Editing an unsigned IPA does not grant that capability;
a signer may strip unsupported entitlements. Ordinary Bluetooth/USB media
controls remain available through the existing media integration.

- https://developer.apple.com/documentation/carplay/requesting-carplay-entitlements
- https://developer.apple.com/documentation/carplay/displaying-content-in-carplay

## Device acceptance still required

Test a car-only launch with the phone locked; browsing and selecting downloads,
favorites and recent tracks; rapid queue selections; a phone-side reorder/delete
while a car row is visible; steering-wheel controls, pause/resume, artwork/time,
route changes, disconnect/reconnect and opening the phone after car-only launch.
Check empty catalogs and failed/offline stream resolution. A successful compile
and Dart tests do not establish real head-unit acceptance.
