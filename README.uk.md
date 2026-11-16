# HDMI Autostart для Kivi 24HK30B

🇬🇧 [English](README.md) · 🇺🇦 **Українська**

Крихітний Android-застосунок (~9 КБ, без іконки та інтерфейсу), який при ввімкненні телевізора **автоматично перемикає його на HDMI2**.

Штатна прошивка Kivi 24HK30B не запам'ятовує останнє джерело сигналу і завжди стартує з лаунчера Kivi, а в меню немає ні налаштування «джерело при ввімкненні», ні HDMI-CEC. Цей застосунок вирішує проблему: через ~4 с після завантаження системи відкриває TV-плеєр MStar на вході HDMI2.

## Пристрій

Перевірено на одному конкретному телевізорі. На інших моделях/прошивках може не працювати без змін.

| Параметр | Значення |
|---|---|
| Телевізор | **Kivi 24HK30B** (24", HD) |
| Android | 6.0.1 (API 23), Android TV |
| Патч безпеки | 2016-04-01 |
| Збірка (`ro.build.display.id`) | `ctl_iptv_mrvl-eng 6.0.1 M5C14J eng.inkyu28.kim.20160629.175740 release-keys` |
| Fingerprint | `CTL/ctl_iptv_mrvl/ctl_iptv_mrvl:6.0.1/M5C14J/inkyu28.kim06291758:eng/release-keys` |
| `ro.build.type` | `userdebug` (`ro.debuggable=1`, працює `adb root`) |
| SoC | MStar, кодова назва **Mainz** (`ro.hardware=mainz`), arm64-v8a |
| Ядро | Linux 3.10.86 |
| RAM | ~1 ГБ (MemTotal 910 МБ) |
| `/data` | 4.4 ГБ |
| `services.jar` | від 2020-09-29 (модифікований Kivi, див. нижче) |
| STR | `mstar.str.enable=user_mode` (на практиці ТВ при ввімкненні робить повне завантаження) |

> Властивості `ro.product.brand=CTL`, `ro.product.manufacturer=LGE`, `ro.board.platform=marvellberlin` успадковані від чужого шаблону збірки й не відповідають реальному залізу. Фактична платформа — MStar (пакети `com.mstar.*`, блочні пристрої `mstar_mci.0`).

Ключові системні пакети:

- `com.kivi.launcher_v2` — домашній екран Kivi (HOME).
- `com.mstar.tv.tvplayer.ui` — TV-плеєр MStar, відповідає за ефірне ТБ та HDMI/AV входи.
- `com.mstar.tv.service`, `com.mstar.android.tv.app` — TV-сервіси MStar.
- Стандартних сервісів Android `tv_input` (TIF) і `hdmi_control` (CEC) **немає**.

## Як це працює

Перемикання входу виконує `RootActivity` TV-плеєра MStar, якому передається extra `inputSrc` з номером джерела:

```bash
adb shell am start \
  -n com.mstar.tv.tvplayer.ui/.RootActivity \
  -a com.mstar.android.intent.action.START_TV_PLAYER \
  --ei inputSrc 24
```

Застосунок робить те саме з `BroadcastReceiver` на `BOOT_COMPLETED`, із затримкою 4 с, щоб лаунчер Kivi встиг завантажитися.

### Номери джерел (`EN_INPUT_SOURCE_TYPE` MStar)

| Джерело | `inputSrc` | Статус |
|---|---|---|
| HDMI1 | 23 | за enum MStar, не перевірено |
| **HDMI2** | **24** | перевірено (логи `setInputSource(24) Success`) |
| HDMI3 | 25 | за enum MStar, не перевірено |
| Лаунчер / Android (STORAGE) | 34 | перевірено (`getCurrentInputSource` на головному екрані) |

Поточне джерело можна побачити так:

```bash
adb logcat | grep -E "setInputSource|getCurrentInputSource"
```

### Чому потрібна установка в `/system`

Kivi модифікували `ActivityStackSupervisor` у `services.jar`: метод `shouldStartActivityMayWait()` блокує запуск Activity з процесу, який зараз не на екрані, якщо застосунок не системний. У логах це виглядає так:

```
E ActivityManager: Check start activity pre-condition fail, the process which calling activity belongs to is not visible
```

Звичайний (user) застосунок з фону відкрити плеєр не може. Застосунок у `/system/app` проходить перевірку `checkIsSystemAppType()` і працює.

## Збірка

Gradle не потрібен. Потрібні:

- JDK 17+ (`javac`, `keytool`);
- Android build-tools (`aapt`, `d8`, `zipalign`, `apksigner`), перевірено з **34.0.0**;
- `android.jar` платформи **23** (Android 6.0).

Структура каталогу `$SDK`, яку очікує скрипт:

```
$SDK/
├── jdk/          # розпакований JDK (bin/javac ...)
├── android-14/   # розпакований build-tools_r34-linux.zip
└── android-6.0/  # розпакований platform-23_r03.zip (android.jar)
```

Завантаження:

```bash
mkdir -p ~/android-mini-sdk && cd ~/android-mini-sdk
curl -fLO https://dl.google.com/android/repository/build-tools_r34-linux.zip
curl -fLO https://dl.google.com/android/repository/platform-23_r03.zip
curl -fL -o jdk.tgz "https://api.adoptium.net/v3/binary/latest/21/ga/linux/x64/jdk/hotspot/normal/eclipse"
unzip -q build-tools_r34-linux.zip && unzip -q platform-23_r03.zip
mkdir jdk && tar xzf jdk.tgz -C jdk --strip-components=1
```

Збірка:

```bash
SDK=~/android-mini-sdk ./build.sh
```

Результат — `hdmi-autostart.apk`. При першій збірці створюється `debug.keystore` (у git не потрапляє).

> Код навмисно без анонімних/вкладених класів: d8 з build-tools 34 падає з `NullPointerException` на внутрішніх класах, скомпільованих javac 21.

## Встановлення на ТВ

1. Увімкнути налагодження по мережі. На цій прошивці ADB по TCP уже доступний:

   ```bash
   adb connect <IP_ТВ>:5555
   adb root
   adb connect <IP_ТВ>:5555
   ```

2. Покласти APK у `/system/app`:

   ```bash
   adb shell 'mount -o rw,remount /system && mkdir -p /system/app/HdmiAutostart'
   adb push hdmi-autostart.apk /system/app/HdmiAutostart/HdmiAutostart.apk
   adb shell 'chmod 755 /system/app/HdmiAutostart && chmod 644 /system/app/HdmiAutostart/HdmiAutostart.apk && chcon u:object_r:system_file:s0 /system/app/HdmiAutostart /system/app/HdmiAutostart/HdmiAutostart.apk && sync && mount -o ro,remount /system'
   adb reboot
   ```

3. Перевірка після перезавантаження:

   ```bash
   adb logcat -d | grep -E "hdmiautostart|setInputSource"
   ```

   Очікується `Start proc ...ua.redacid.hdmiautostart ... for broadcast` і `setInputSource(24) Success`.

Ручний тест без перезавантаження (з головного екрана):

```bash
adb shell am broadcast -a ua.redacid.hdmiautostart.TEST -n ua.redacid.hdmiautostart/.BootReceiver
```

## Видалення

```bash
adb root
adb shell 'mount -o rw,remount /system && rm -r /system/app/HdmiAutostart && mount -o ro,remount /system'
adb reboot
```

## Налаштування

У [`BootReceiver.java`](src/ua/redacid/hdmiautostart/BootReceiver.java):

- `INPUT_SRC_HDMI2` — номер входу (див. таблицю вище);
- `DELAY_MS` — затримка після завантаження (за замовчуванням 4000 мс).

Після зміни перезібрати та замінити APK у `/system/app/HdmiAutostart/`.

## Обмеження

- Обробляється лише `BOOT_COMPLETED`. Якщо ТВ буде виходити зі сну (STR) без повного завантаження, перемикання не спрацює.
- Перемикання відбувається завжди, навіть якщо до вимкнення було інше джерело.
- Оновлення прошивки Kivi через USB/OTA, найімовірніше, зітре `/system/app/HdmiAutostart`.

## Відмова від відповідальності

Зміна системного розділу виконується на власний ризик. Автор не несе відповідальності за пошкодження пристрою.
