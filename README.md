# HDMI Autostart for Kivi 24HK30B

🇬🇧 **English** · 🇺🇦 [Українська](README.uk.md)

A tiny Android app (~9 KB, no icon, no UI) that **automatically switches the TV to HDMI2 on power-on**.

The stock Kivi 24HK30B firmware does not remember the last input source and always boots into the Kivi launcher. Its settings menu has no "power-on source" option and no HDMI-CEC. This app fixes that: ~4 s after the system boots, it opens the MStar TV player on the HDMI2 input.

## Device

Tested on one specific TV. Other models or firmware versions may need changes.

| Property | Value |
|---|---|
| TV | **Kivi 24HK30B** (24", HD) |
| Android | 6.0.1 (API 23), Android TV |
| Security patch | 2016-04-01 |
| Build (`ro.build.display.id`) | `ctl_iptv_mrvl-eng 6.0.1 M5C14J eng.inkyu28.kim.20160629.175740 release-keys` |
| Fingerprint | `CTL/ctl_iptv_mrvl/ctl_iptv_mrvl:6.0.1/M5C14J/inkyu28.kim06291758:eng/release-keys` |
| `ro.build.type` | `userdebug` (`ro.debuggable=1`, `adb root` works) |
| SoC | MStar, codename **Mainz** (`ro.hardware=mainz`), arm64-v8a |
| Kernel | Linux 3.10.86 |
| RAM | ~1 GB (MemTotal 910 MB) |
| `/data` | 4.4 GB |
| `services.jar` | dated 2020-09-29 (modified by Kivi, see below) |
| STR | `mstar.str.enable=user_mode` (in practice the TV does a full boot on power-on) |

> The properties `ro.product.brand=CTL`, `ro.product.manufacturer=LGE` and `ro.board.platform=marvellberlin` are inherited from someone else's build template and do not match the real hardware. The actual platform is MStar (`com.mstar.*` packages, `mstar_mci.0` block devices).

Key system packages:

- `com.kivi.launcher_v2`: Kivi home screen (HOME).
- `com.mstar.tv.tvplayer.ui`: MStar TV player, handles broadcast TV and HDMI/AV inputs.
- `com.mstar.tv.service`, `com.mstar.android.tv.app`: MStar TV services.
- The standard Android `tv_input` (TIF) and `hdmi_control` (CEC) services are **absent**.

## How it works

Input switching is done by the MStar TV player's `RootActivity`, which takes an `inputSrc` extra with the source number:

```bash
adb shell am start \
  -n com.mstar.tv.tvplayer.ui/.RootActivity \
  -a com.mstar.android.intent.action.START_TV_PLAYER \
  --ei inputSrc 24
```

The app does the same from a `BroadcastReceiver` on `BOOT_COMPLETED`, with a 4 s delay so the Kivi launcher finishes starting first.

### Source numbers (MStar `EN_INPUT_SOURCE_TYPE`)

| Source | `inputSrc` | Status |
|---|---|---|
| HDMI1 | 23 | per MStar enum, not verified |
| **HDMI2** | **24** | verified (`setInputSource(24) Success` in logs) |
| HDMI3 | 25 | per MStar enum, not verified |
| Launcher / Android (STORAGE) | 34 | verified (`getCurrentInputSource` on home screen) |

To see the current source:

```bash
adb logcat | grep -E "setInputSource|getCurrentInputSource"
```

### Why it must be installed in `/system`

Kivi modified `ActivityStackSupervisor` in `services.jar`: the method `shouldStartActivityMayWait()` blocks activity starts from a process that is not currently on screen, unless the caller is a system app. The log shows:

```
E ActivityManager: Check start activity pre-condition fail, the process which calling activity belongs to is not visible
```

A regular (user) app cannot open the player from the background. An app in `/system/app` passes the `checkIsSystemAppType()` check and works.

## Building

No Gradle needed. Requirements:

- JDK 17+ (`javac`, `keytool`);
- Android build-tools (`aapt`, `d8`, `zipalign`, `apksigner`), tested with **34.0.0**;
- `android.jar` for platform **23** (Android 6.0).

Directory layout expected by the script in `$SDK`:

```
$SDK/
├── jdk/          # unpacked JDK (bin/javac ...)
├── android-14/   # unpacked build-tools_r34-linux.zip
└── android-6.0/  # unpacked platform-23_r03.zip (android.jar)
```

Download:

```bash
mkdir -p ~/android-mini-sdk && cd ~/android-mini-sdk
curl -fLO https://dl.google.com/android/repository/build-tools_r34-linux.zip
curl -fLO https://dl.google.com/android/repository/platform-23_r03.zip
curl -fL -o jdk.tgz "https://api.adoptium.net/v3/binary/latest/21/ga/linux/x64/jdk/hotspot/normal/eclipse"
unzip -q build-tools_r34-linux.zip && unzip -q platform-23_r03.zip
mkdir jdk && tar xzf jdk.tgz -C jdk --strip-components=1
```

Build:

```bash
SDK=~/android-mini-sdk ./build.sh
```

Output: `hdmi-autostart.apk`. The first build creates `debug.keystore` (git-ignored).

> The code deliberately avoids anonymous/inner classes: d8 from build-tools 34 crashes with a `NullPointerException` on inner classes compiled by javac 21.

## Installing on the TV

1. Connect over ADB. On this firmware, ADB over TCP is already enabled:

   ```bash
   adb connect <TV_IP>:5555
   adb root
   adb connect <TV_IP>:5555
   ```

2. Put the APK into `/system/app`:

   ```bash
   adb shell 'mount -o rw,remount /system && mkdir -p /system/app/HdmiAutostart'
   adb push hdmi-autostart.apk /system/app/HdmiAutostart/HdmiAutostart.apk
   adb shell 'chmod 755 /system/app/HdmiAutostart && chmod 644 /system/app/HdmiAutostart/HdmiAutostart.apk && chcon u:object_r:system_file:s0 /system/app/HdmiAutostart /system/app/HdmiAutostart/HdmiAutostart.apk && sync && mount -o ro,remount /system'
   adb reboot
   ```

3. Verify after reboot:

   ```bash
   adb logcat -d | grep -E "hdmiautostart|setInputSource"
   ```

   Expect `Start proc ...ua.redacid.hdmiautostart ... for broadcast` and `setInputSource(24) Success`.

Manual test without rebooting (from the home screen):

```bash
adb shell am broadcast -a ua.redacid.hdmiautostart.TEST -n ua.redacid.hdmiautostart/.BootReceiver
```

## Uninstalling

```bash
adb root
adb shell 'mount -o rw,remount /system && rm -r /system/app/HdmiAutostart && mount -o ro,remount /system'
adb reboot
```

## Configuration

In [`BootReceiver.java`](src/ua/redacid/hdmiautostart/BootReceiver.java):

- `INPUT_SRC_HDMI2`: input number (see table above);
- `DELAY_MS`: delay after boot (default 4000 ms).

After changing, rebuild and replace the APK in `/system/app/HdmiAutostart/`.

## Limitations

- Only `BOOT_COMPLETED` is handled. If the TV ever resumes from sleep (STR) without a full boot, the switch won't happen.
- The switch always happens, even if a different source was active before power-off.
- A Kivi firmware update via USB/OTA will most likely wipe `/system/app/HdmiAutostart`.

## Disclaimer

Modifying the system partition is at your own risk. The author is not responsible for any damage to the device.
