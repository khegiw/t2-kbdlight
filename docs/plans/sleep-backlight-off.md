# Sleep Backlight Off Plan

- [x] Confirm the sleep callback does not power off the keyboard backlight.
- [x] Serialize sleep state and power-off with the restore queue.
- [x] Prevent queued or fallback restores while sleeping.
- [x] Verify strict compilation and plist validity.
- [x] Install and verify with a real sleep/wake cycle.

## Success criteria

- The T2 receives the LED power-off report before macOS sleep is acknowledged.
- Pending restore work cannot turn the LEDs on while the system is sleeping.
- Wake restoration continues to succeed.

## Result

The daemon logged `backlight disabled for sleep` at 04:48:31 UTC, detected wake at 04:48:54 UTC, and restored the backlight on the first attempt at 04:48:55 UTC.
