# T2 Keyboard Backlight Bypass ✨

A small utility that tells the keyboard backlight on a 2019 16-inch Intel MacBook Pro (MacBookPro16,1) to stop waiting for an ambient-light sensor that is no longer present.

It sends feature reports directly to the T2 Touch Bar Backlight HID interface. That bypasses macOS ambient-light-sensor control and sets the keyboard backlight to maximum brightness.

This was built for a Mac whose display assembly and ambient-light sensor are unavailable. It does not repair damaged display hardware. It only drives the keyboard backlight. Hardware does not care about optimism; it responds to the right bytes.

![A headless MacBook Pro with its keyboard backlight glowing](assets/macbook-keyboard-cropped.jpg)


## Requirements

- macOS on `MacBookPro16,1`
- Xcode Command Line Tools
- Administrator access

First, verify the Mac model:

```sh
system_profiler SPHardwareDataType | grep 'Model Identifier'
```

Expected result:
Model Identifier: MacBookPro16,1

If the identifier differs, stop. Do not infer protocol compatibility from a similar product name. Apple shipped multiple machines that look alike and behave differently at the hardware interface.

## Build

```sh
clang -fobjc-arc -framework Foundation -framework IOKit t2-kbdlight.m -o t2-kbdlight
```

## Switch on the glow

```sh
sudo ./t2-kbdlight
```

If the T2 is happy, it answers with three zeroes:

```text
power-off report: 0x0
brightness report: 0x0
power report: 0x0
```

## Make it a command

```sh
sudo install -m 755 t2-kbdlight /usr/local/bin/t2-kbdlight
sudo t2-kbdlight
```

## Keep the party going after sleep

Install the included LaunchDaemon after installing the command:

```sh
sudo install -m 644 local.t2-kbdlight.plist /Library/LaunchDaemons/local.t2-kbdlight.plist
sudo launchctl bootstrap system /Library/LaunchDaemons/local.t2-kbdlight.plist
```

The daemon applies the brightness at startup and every 30 seconds, bringing the glow back shortly after wake. Check whether your tiny lighting technician is working:

```sh
sudo launchctl print system/local.t2-kbdlight
sudo tail -n 20 /var/log/t2-kbdlight.log
```

Had enough ambience? Remove the daemon with:

```sh
sudo launchctl bootout system /Library/LaunchDaemons/local.t2-kbdlight.plist
sudo rm /Library/LaunchDaemons/local.t2-kbdlight.plist
```

## The sensible warning section

- The utility is intentionally hard-coded for the verified T2 HID device and half brightness (`30/60`).
- It power-cycles the LEDs and enables the T2 override required when the ambient sensor is unavailable.
- It briefly requests exclusive access to the HID interface and immediately releases it.
- It uses an undocumented hardware protocol and may stop working after a macOS or firmware update.
- The optional LaunchDaemon re-applies the setting every 30 seconds.
- Do not use it on another Mac model without confirming that model's HID protocol.
- Successful report delivery does not prove that physically damaged keyboard LEDs or cables can illuminate.

## What it whispers to the T2

The utility selects USB vendor `0x05ac`, product `0x8102`, vendor usage page `0xff00`, usage `15`. Feature report `0x03` first powers the LEDs off. After 250 milliseconds, feature report `0x01` sets brightness to `30` out of `60` with the hardware override enabled, then report `0x03` powers the LEDs on. Off, breathe, glow.

The protocol was cross-checked against the T2 Linux [`apple-ib-drv`](https://github.com/t2linux/apple-ib-drv/pull/4) implementation for `MacBookPro16,1`.
