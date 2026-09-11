# T2 keyboard backlight bypass

This utility turns the keyboard backlight on at half brightness on a 2019 16-inch Intel MacBook Pro (`MacBookPro16,1`). It sends feature reports directly to the T2 `Touch Bar Backlight` HID interface, bypassing macOS ambient-light-sensor control.

This was created for a Mac whose built-in display assembly and ambient-light sensor are unavailable. It is not a repair for the broken display hardware.

## Requirements

- macOS on `MacBookPro16,1`
- Xcode Command Line Tools
- Administrator access

Confirm the model before using it:

```sh
system_profiler SPHardwareDataType | grep 'Model Identifier'
```

The expected result is `MacBookPro16,1`.

## Build

```sh
clang -fobjc-arc -framework Foundation -framework IOKit t2-kbdlight.m -o t2-kbdlight
```

## Enable the keyboard light

```sh
sudo ./t2-kbdlight
```

Success looks like this:

```text
power-off report: 0x0
brightness report: 0x0
power report: 0x0
```

## Install the command

```sh
sudo install -m 755 t2-kbdlight /usr/local/bin/t2-kbdlight
sudo t2-kbdlight
```

## Restore the light after sleep

Install the included LaunchDaemon after installing the command:

```sh
sudo install -m 644 com.khegiw.t2-kbdlight.plist /Library/LaunchDaemons/com.khegiw.t2-kbdlight.plist
sudo launchctl bootstrap system /Library/LaunchDaemons/com.khegiw.t2-kbdlight.plist
```

The daemon applies the brightness at startup and every 30 seconds, restoring it shortly after wake. Check its status and latest output with:

```sh
sudo launchctl print system/com.khegiw.t2-kbdlight
sudo tail -n 20 /var/log/t2-kbdlight.log
```

To remove the daemon:

```sh
sudo launchctl bootout system /Library/LaunchDaemons/com.khegiw.t2-kbdlight.plist
sudo rm /Library/LaunchDaemons/com.khegiw.t2-kbdlight.plist
```

## Important limitations

- The utility is intentionally hard-coded for the verified T2 HID device and half brightness.
- It power-cycles the LEDs and enables the T2 override required when the ambient sensor is unavailable.
- It briefly requests exclusive access to the HID interface and immediately releases it.
- It uses an undocumented hardware protocol and may stop working after a macOS or firmware update.
- The optional LaunchDaemon re-applies the setting every 30 seconds.
- Do not use it on another Mac model without confirming that model's HID protocol.
- Successful report delivery does not prove that physically damaged keyboard LEDs or cables can illuminate.

## Protocol

The utility selects USB vendor `0x05ac`, product `0x8102`, vendor usage page `0xff00`, usage `15`. Feature report `0x03` first powers the LEDs off. After 250 milliseconds, feature report `0x01` sets brightness to `30` out of `60` with the hardware override enabled, then report `0x03` powers the LEDs on.

The protocol was cross-checked against the T2 Linux [`apple-ib-drv`](https://github.com/t2linux/apple-ib-drv/pull/4) implementation for `MacBookPro16,1`.
