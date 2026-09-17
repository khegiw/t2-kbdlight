# Sleep Backlight Off Review

## Cause

The power callback acknowledged `kIOMessageSystemWillSleep` without sending the T2 LED power-off report. A delayed restore could also remain queued across the sleep transition.

## Fix

- Send the power-off report on `kIOMessageSystemWillSleep` before acknowledging sleep.
- Serialize sleep state and HID operations on the restore queue.
- Skip both newly requested and already delayed restores while sleeping.
- Clear sleep state and retain the existing wake restoration behavior after wake.

## Verification

- Strict Objective-C compilation with warnings treated as errors passed.
- `plutil -lint local.t2-kbdlight.plist` passed.
- The installed LaunchDaemon remained running.
- A real sleep/wake cycle logged power-off before sleep and restored the backlight on the first wake attempt.
