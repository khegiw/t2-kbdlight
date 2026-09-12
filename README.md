# T2 Keyboard Backlight Bypass ✨

![A headless MacBook Pro with its keyboard backlight glowing](assets/macbook-keyboard-cropped.jpg)

Utility for setting the keyboard backlight to maximum brightness on a 2019 16-inch Intel MacBook Pro (`MacBookPro16,1`) without an ambient-light sensor.

It sends feature reports to the T2 `Touch Bar Backlight` HID interface. It does not repair display hardware.

## Requirements

* macOS on `MacBookPro16,1`
* Xcode Command Line Tools
* Administrator access

Verify the model:

```bash
system_profiler SPHardwareDataType | grep 'Model Identifier'
```

Expected:

```text
Model Identifier: MacBookPro16,1
```

Stop if the identifier differs.

## Build

```bash
clang -fobjc-arc \
  -framework Foundation \
  -framework IOKit \
  t2-kbdlight.m \
  -o t2-kbdlight
```

## Run

```bash
sudo ./t2-kbdlight
```

Expected output:

```text
brightness report: 0x0
power report: 0x0
```

The keyboard backlight should turn on at maximum brightness.

Run the command again after sleep or restart if needed.

## Install

```bash
sudo install -m 755 t2-kbdlight /usr/local/bin/t2-kbdlight
sudo t2-kbdlight
```

## Limitations

* Supports only the verified `MacBookPro16,1` HID interface.
* Sets maximum brightness only.
* Uses an undocumented protocol and may break after updates.
* Does not repair LEDs, cables, connectors, power paths, or display hardware.
* Successful reports confirm interface acceptance, not physical hardware function.

## Protocol

| Property          |    Value |
| ----------------- | -------: |
| USB vendor        | `0x05ac` |
| USB product       | `0x8102` |
| Vendor usage page | `0xff00` |
| Usage             |     `15` |

Reports:

| Report | Purpose                     |
| ------ | --------------------------- |
| `0x01` | Sets brightness to `60`     |
| `0x03` | Powers on the keyboard LEDs |

The protocol was cross-checked against the T2 Linux [`apple-ib-drv`](https://github.com/t2linux/apple-ib-drv/pull/4) implementation for `MacBookPro16,1`.

Use only on the verified hardware.

