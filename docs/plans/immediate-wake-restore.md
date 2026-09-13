# Restore keyboard light promptly after wake

- [x] Replace 30-second polling with IOKit power notifications.
- [x] Add bounded HID discovery and open retries.
- [x] Add timestamped runtime logging.
- [x] Retain a low-frequency fallback.
- [x] Compile and validate the service definition.
- [x] Install and verify the persistent service.
- [x] Perform a sleep and wake test.
- [x] Push the verified change.

Success requires a logged wake notification followed by a successful restore without waiting for a polling interval.
