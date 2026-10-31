# REGRESSIONS.md — Известные регрессии и их статус

## 1. Логин по номеру (Приоритет: P0)
- **Симптом:** Ошибка подключения или тайм-аут при попытке входа по номеру телефона в прошлых форках (базы 8.8 и 11.11).
- **Причины:**
  1. `Network.framework` (iOS 12+) в сетевом слое вместо BSD-сокетов. В `submodules/Reachability` и `Network.swift` проверены ветки для iOS < 12 (`WrappedLegacyReachability`), сетевой стек MTProtoKit ходит через BSD-сокеты (`GCDAsyncSocket`).
  2. Устаревший отпечаток TLS handshake (Safari ClientHello), отвергаемый серверами Telegram MTProto.
- **Устранение:**
  - Черри-пик современного TLS ClientHello из апстрима (`3d6fabea330b3e44ed986154ccbda29748403b27`) в `submodules/MtProtoKit/Sources/MTTcpConnection.m`: динамическая генерация ML-KEM открытого ключа, Grease-значений и расширений.
  - Устранена сериализация URL-safe Base64 в `MTApiEnvironment.m`.
  - Подавлены устаревшие предупреждения `SecKeyEncrypt` под `-Werror` в `MTRsa.m`.
- **Статус:** Собрано, на устройстве не проверено (P0).

---

## 2. Кружки / Round Video Messages (Приоритет: P0)
- **Симптом:** Падение или ошибка записи/отправки видео-сообщений на iOS 10.
- **Причины:**
  1. `TGVideoCameraPipeline.m` вызывает `videoSettingsForPreset:` в `TGMediaVideoConverter.m`, где использовалась константа `AVVideoCodecKey: AVVideoCodecTypeH264`. Константа появилась только в iOS 11.0; на iOS 10.3 символ равен `nil`, что вызывало исключение при формировании словаря параметров `AVAssetWriterInput`.
  2. `LegacyInstantVideoController.swift`: вызов `NSKeyedArchiver.archivedData(withRootObject:requiringSecureCoding:)` падал с `unrecognized selector` на iOS 10 при сохранении корректировок (триминга) кружка.
  3. `ChatMessageInstantVideoBubbleContentNode.swift`: свойство `CornerLayer.init(cornerMask: CACornerMask)` и доступ к `contentLayer.maskedCorners` требовали iOS 11+, вызывая падение баббла кружка при отображении.
  4. `CameraOutput.swift` и `MediaEditorValues.swift`: обращение к HEVC и `kVTProfileLevel_HEVC_Main_AutoLevel` без гварда на iOS 10.
- **Устранение:**
  - В `TGMediaVideoConverter.m` добавлена проверка `@available(iOS 11.0, *)` для H.264/HEVC; на iOS 10 используется константа `AVVideoCodecH264` (`@"avc1"`).
  - В `LegacyInstantVideoController.swift`, `LegacyMediaPickers.swift`, `ShareItems.swift` добавлен fallback на `NSKeyedArchiver.archivedData(withRootObject:)` на iOS 10.
  - В `ChatMessageInstantVideoBubbleContentNode.swift` задействован `DeviceCornerMask` с вычислением смещений без обращения к системному `maskedCorners`.
  - В `CameraOutput.swift` и `MediaEditorValues.swift` константы HEVC и выбор кодека заблокированы на iOS 10 с принудительным H.264.
- **Статус:** Собрано, на устройстве не проверено (P0).

---

## 3. Системные API iOS 11+ в UI и рантайме (P0)
- **Симптом:** Падения в рантайме и ошибки сборки при компиляции под iOS 10.3.
- **Устранение:**
  1. `layer.maskedCorners` — все прямые обращения во всех UI-компонентах обернуты в `if #available(iOS 11.0, *)` либо переведены на `DeviceCornerMask`.
  2. `UIScrollView.contentInsetAdjustmentBehavior` — изолировано во всех 41 файлах кодовой базы под `if #available(iOS 11.0, *)`.
  3. `UIDropInteractionDelegate` / `UIDropInteraction` — вызовы добавления интеракций в `ChatController`, `DrawingScreen`, `MediaEditorScreen` обернуты в `#available(iOS 11.0, *)`.
  4. `PDFKit` в `BrowserUI` — класс `BrowserPdfContent` помечен `@available(iOS 11.0, *)`, в `BrowserScreen` добавлен fallback на `BrowserDocumentContent` на iOS 10.
  5. `Vision` / `CoreML` — методы и импорты изолированы под `#available`, неиспользуемые импорты удалены.
- **Статус:** Собрано, на устройстве не проверено (P0).

---

## 4. Ошибка установки: неизвестные точки расширений в installd (P0)
- **Симптом:** При установке IPA на iOS 10.3.3 системный демон `installd` падает с ошибкой:
  `Appex bundle at .../BroadcastUploadExtension.appex ... specifies a value (com.apple.broadcast-services-upload) for the NSExtensionPointIdentifier key in its Info.plist NSExtension dictionary that does not correspond to a known extension point.`
- **Причина:**
  1. `BroadcastUploadExtension` использует `com.apple.broadcast-services-upload` (ReplayKit broadcast upload, iOS 11+).
  2. `WidgetExtension` использует `com.apple.widgetkit-extension` (WidgetKit, iOS 14+).
  Демон `installd` в iOS 10.3.3 валидирует все `.appex` в папке `PlugIns/` приложения по своей таблице известных точек расширения; если идентификатор неизвестен ОС, установка приложения аварийно прерывается.
- **Устранение:**
  - В `Telegram/BUILD` исключены `:BroadcastUploadExtension` и `:WidgetExtension` из таргета `extensions`.
  - Сохранены нативные расширения, полностью поддерживаемые в iOS 10: `:ShareExtension` (`com.apple.share-services`), `:NotificationContentExtension` (`com.apple.usernotifications.content-extension`), `:NotificationServiceExtension` (`com.apple.usernotifications.service`) и `:IntentsExtension` (`com.apple.intents-service`).
- **Статус:** Исправлено в коммите `d8cdb20c33`. Проверено: приложение успешно устанавливается на iPhone 5s.

---

## 5. Падение при холодном старте: dyld Library not loaded DeviceCheck.framework (P0)
- **Симптом:** При открытии приложения на iPhone 5s (iOS 10.3.3) происходит мгновенный вылет до отрисовки первого кадра.
- **Данные крэш-репорта (снят напрямую с подключенного iPhone 5s через `idevicecrashreport`):**
  - Incident: `C4746B7C-AB88-4678-94D7-D670944220F2`
  - Exception Type: `EXC_CRASH (SIGABRT)`
  - Termination Description: `DYLD, Library not loaded: /System/Library/Frameworks/DeviceCheck.framework/DeviceCheck | Referenced from: .../Telegram.app/Frameworks/TelegramUIFramework.framework/TelegramUIFramework | Reason: image not found`
- **Причина:**
  `DeviceCheck.framework` появился только в iOS 11.0. На iOS 10.3.3 системный путь `/System/Library/Frameworks/DeviceCheck.framework` отсутствует. `TelegramUIFramework` линковал его с командой `LC_LOAD_DYLIB` (жёсткая зависимость) из-за `import DeviceCheck` в `AppDelegate.swift` и транзитивной зависимости из Google `RecaptchaEnterprise`.
- **Устранение:**
  1. Удален неиспользуемый `import DeviceCheck` из `submodules/TelegramUI/Sources/AppDelegate.swift`.
  2. В `third-party/recaptcha/BUILD` для `RecaptchaEnterprise` добавлен `weak_sdk_frameworks = ["DeviceCheck"]`.
  3. В `Telegram/BUILD` для `TelegramUIFramework` добавлен `linkopts = ["-weak_framework", "DeviceCheck"]`.
  4. Проверено с помощью `otool -l`: команда загрузки `DeviceCheck` изменена с `LC_LOAD_DYLIB` на `LC_LOAD_WEAK_DYLIB`. На iOS 10 dyld игнорирует отсутствие фреймворка и продолжает запуск.
- **Статус:** Исправлено в коммите `12b27ae5f3`. Проверено: ошибка отсутствия `DeviceCheck.framework` полностью устранена dyld.

---

## 6. Падение при старте: dyld Symbol not found __ZNSt19bad_optional_accessD1Ev (P0)
- **Симптом:** При открытии приложения на iPhone 5s (iOS 10.3.3) происходит вылет с крэш-дампом:
  - Incident: `1433E0A3-F2F6-40F7-814A-05F0941C9F67`
  - Termination Description: `DYLD, Symbol not found: __ZNSt19bad_optional_accessD1Ev | Referenced from: .../Telegram.app/Frameworks/TelegramUIFramework.framework/TelegramUIFramework | Expected in: /usr/lib/libc++.1.dylib`
- **Причина:**
  В C++17 классы `std::bad_optional_access`, `std::bad_variant_access` и `std::bad_any_cast` имеют ключевые функции (виртуальный деструктор и `what()`), которые в современных версиях macOS/iOS экспортируются из системной `/usr/lib/libc++.1.dylib` (начиная с iOS 12+). На iOS 10.3.3 системная `libc++.1.dylib` собрана под C++11/14 и не содержит символов `std::bad_optional_access`. Из-за этого при динамической связке dyld аварийно завершал запуск процесса.
- **Устранение:**
  1. Создан модуль обратной совместимости `submodules/LegacyCppCompat` (`LegacyCppCompat.mm`), содержащий реализации виртуального деструктора и методов `what()` для `std::bad_optional_access`, `std::bad_variant_access` и `std::bad_any_cast`.
  2. Модуль подключён в `deps` к `TelegramUIFramework`, `TelegramCoreFramework` и целевому приложению `Telegram` с флагом `alwayslink = True`.
  3. Проверено через `nm -m`: символы теперь экспортируются внутри самого бандла приложения (`__TEXT,__text` в `TelegramCoreFramework`), и загрузчик dyld больше не требует их наличия в `/usr/lib/libc++.1.dylib`.
- **Статус:** Исправлено в коммите `739ca51f02`. Проверено: загрузчик dyld успешно связывает все символы и запускает процесс.

---

## 7. Падение в UI: -[UIScrollView setContentInsetAdjustmentBehavior:]: unrecognized selector (P0)
- **Симптом:** При открытии приложения на iPhone 5s процесс стартует, работает около 3 секунд и падает с `NSInvalidArgumentException`:
  `*** Terminating app due to uncaught exception 'NSInvalidArgumentException', reason: '-[UIScrollView setContentInsetAdjustmentBehavior:]: unrecognized selector sent to instance ...'`
- **Причина:**
  Свойство `UIScrollView.contentInsetAdjustmentBehavior` появилось в iOS 11.0. При показе экрана первого запуска `RMIntroViewController` вызывал сеттер напрямую без гварда доступности.
- **Устранение:**
  1. В `RMIntroViewController.m:356` вызов обёрнут в `@available(iOS 11.0, *)`.
  2. В `submodules/LegacyCppCompat.mm` добавлен конструктор времени загрузки, динамически регистрирующий методы `setContentInsetAdjustmentBehavior:`, `contentInsetAdjustmentBehavior` и `UIView.safeAreaInsets` через `class_addMethod`, если они отсутствуют в системе (на iOS 10). На iOS 11+ системные методы остаются нетронутыми.
- **Статус:** Исправлено в коммите `241661858c`, отправлено на iPhone по USB.

---

## 8. Падение при вводе номера: -[NSURLSessionConfiguration setWaitsForConnectivity:] (P0)
- **Симптом:** При вводе номера телефона и нажатии «Далее» приложение аварийно завершалось:
  `*** Terminating app due to uncaught exception 'NSInvalidArgumentException', reason: '-[__NSCFURLSessionConfiguration setWaitsForConnectivity:]: unrecognized selector sent to instance ...'`
- **Причина:**
  Свойство `NSURLSessionConfiguration.waitsForConnectivity` появилось в iOS 11.0. При отправке сетевого запроса авторизации модуль `tdnet` (`third-party/td/td/tdnet/td/net/DarwinHttp.mm`) конфигурировал `NSURLSession` с вызовом `configuration.waitsForConnectivity = true` без проверки доступности ОС.
- **Устранение:**
  1. В `DarwinHttp.mm` вызовы `waitsForConnectivity` и `networkServiceType = NSURLNetworkServiceTypeResponsiveData` обёрнуты в `@available(iOS 11.0, *)` и `@available(iOS 13.0, *)`.
  2. В `LegacyCppCompat.mm` добавлен глобальный runtime-фолбэк для `setWaitsForConnectivity:`, `waitsForConnectivity`, `setMultipathServiceType:`, `multipathServiceType` на классах `NSURLSessionConfiguration` и закрытом системном классе `__NSCFURLSessionConfiguration`, что предотвращает вылет даже при вызовах из закрытых бинарных фреймворков (например, RecaptchaEnterprise).
- **Статус:** Исправлено в коммите `d59ef37035`, IPA собран и загружен на устройство по USB.

---

## 11. Падение на экране ввода кода авторизации: SIGSEGV в CodeInputView.update / Swift isaMask (P0)
- **Симптом:** Сервер успешно отправляет проверочный код в активный аккаунт Telegram, но в момент перехода на экран ввода кода (`AuthorizationSequenceCodeEntryController`) приложение крашится:
  - Exception Type: `EXC_BAD_ACCESS (SIGSEGV)`
  - Exception Subtype: `KERN_INVALID_ADDRESS at 0x0000000000000000`
  - Thread 0 Crashed: `CodeInputView.update(theme:prefix:count:width:compact:) (CodeInputView.swift:374)`
- **Причина:**
  1. **Фундаментальная несовместимость рантайма Swift 5 с iOS 10 arm64 (`_swift_isaMask`):**
     Начиная со Swift 5.0, компилятор для динамического вызова методов Swift-классов, наследующих от классов Objective-C (`ImmediateTextNode` -> `TextNode` -> `ASDisplayNode`), генерирует маскирование `isa & _swift_isaMask` для извлечения адреса `Class` из non-pointer `isa`.
     В `libswiftCore.dylib` символ `_objc_debug_isa_class_mask` слабо импортируется из системной `libobjc.dylib`. Однако в iOS 10.3.3 `libobjc` не экспортирует `_objc_debug_isa_class_mask` (он появился только в iOS 11/12). Рантайм Swift при отсутствии символа ошибочно выставляет `_swift_isaMask = (uintptr_t)-1` (`0xffffffffffffffffULL`), полагая, что платформа не использует non-pointer isa. На iOS 10 arm64 non-pointer isa активно используется и содержит magic bits в битах 33..63 (`ISA_MASK = 0x00000001fffffff8ULL`). В итоге маска `-1` оставляла magic bits в адресе класса, что приводило к вызову vtable по мусорному адресу и обнулению регистра `x22`, вызывая немедленный SIGSEGV при разыменовании `0x0`.
  2. В `CodeInputView.swift` обращение к `self.view.addSubview(self.backgroundView)` находилось прямо внутри `ASDisplayNode.init()`, вызывая форсированную синхронную инициализацию UIKit-представления до добавления узла в иерархию отображения.
  3. Жест авторизации через QR-код (`debugQrTap`) на экране ввода номера телефона был заблокирован директивой `#if DEBUG`.
- **Устранение:**
  1. В `submodules/LegacyCppCompat.mm` объявлена и экспортирована глобальная переменная `uintptr_t _objc_debug_isa_class_mask = 0x00000001fffffff8ULL`, удовлетворяющая слабый импорт `libswiftCore.dylib`.
  2. Добавлен конструктор раннего приоритета `fixup_swift_isa_mask()` (`__attribute__((constructor(101)))`), явно патчащий `_swift_isaMask` по `dlsym(RTLD_DEFAULT, "_swift_isaMask")` значением `0x00000001fffffff8ULL`.
  3. В `CodeInputView.swift` вызов `insertSubview(self.backgroundView, at: 0)` перенесён из `init()` в метод жизненного цикла `didLoad()`.
  4. В `AuthorizationSequencePhoneEntryControllerNode.swift` снята директива `#if DEBUG` с `debugQrTap` (жест по тексту подсказки) и улучшено центрирование QR-кода на узком экране 320pt.
- **Статус:** Исправлено в коммите `dae4f0b99e`. IPA собран и загружен на подключенный iPhone 5s по USB.


---

## 9. Пустой экран выбора кода страны (P1)
- **Симптом:** При открытии экрана выбора страны таблица отображалась пустой (только разделители/белое поле и открытая клавиатура), страны и телефонные коды отсутствовали.
- **Причина:**
  В `CountrySelectionUI`:
  1. На чистой установке `engine.localization.getCountriesList` возвращает пустой список (`[]`) из локального кэша sharedData до завершения сетевого ответа. Метод `loadServerCountryCodes` безусловно присваивал `countryCodes = countries`, затирая встроенную локальную базу `PhoneCountries.txt` пустым массивом.
  2. В `loadCountryCodes()` парсер ожидал только `\r\n` разделители строк. При расхождениях форматов строк парсинг мог завершаться досрочно.
- **Устранение:**
  1. В `AuthorizationSequenceCountrySelectionController.swift` запрещено перезаписывать `countryCodes` пустым списком (`if !countries.isEmpty`).
  2. Добавлен автоматический откат к чтению `PhoneCountries.txt`, если список стран пуст.
  3. В парсерах `PhoneCountries.txt` поддержана обработка как `\r\n`, так и `\n`.
  4. В `AuthorizationSequenceCountrySelectionControllerNode.swift` добавлен вызов `reloadData()` при инициализации и скорректирован нижний инсет таблицы с учётом высоты клавиатуры `layout.inputHeight`.
- **Статус:** Исправлено в коммите `d59ef37035`, IPA собран и загружен на устройство по USB.

---

## 11. Падение на экране ввода кода авторизации: SIGSEGV в CodeInputView.update / Swift isaMask (P0)
- **Симптом:** Сервер успешно отправляет проверочный код в активный аккаунт Telegram, но в момент перехода на экран ввода кода (`AuthorizationSequenceCodeEntryController`) приложение крашится:
  - Exception Type: `EXC_BAD_ACCESS (SIGSEGV)`
  - Exception Subtype: `KERN_INVALID_ADDRESS at 0x0000000000000000`
  - Thread 0 Crashed: `CodeInputView.update(theme:prefix:count:width:compact:) (CodeInputView.swift:374)`
- **Причина:**
  1. **Фундаментальная несовместимость рантайма Swift 5 с iOS 10 arm64 (`_swift_isaMask`):**
     Начиная со Swift 5.0, компилятор для динамического вызова методов Swift-классов, наследующих от классов Objective-C (`ImmediateTextNode` -> `TextNode` -> `ASDisplayNode`), генерирует маскирование `isa & _swift_isaMask` для извлечения адреса `Class` из non-pointer `isa`.
     В `libswiftCore.dylib` символ `_objc_debug_isa_class_mask` слабо импортируется из системной `libobjc.dylib`. Однако в iOS 10.3.3 `libobjc` не экспортирует `_objc_debug_isa_class_mask` (он появился только в iOS 11/12). Рантайм Swift при отсутствии символа ошибочно выставляет `_swift_isaMask = (uintptr_t)-1` (`0xffffffffffffffffULL`), полагая, что платформа не использует non-pointer isa. На iOS 10 arm64 non-pointer isa активно используется и содержит magic bits в битах 33..63 (`ISA_MASK = 0x00000001fffffff8ULL`). В итоге маска `-1` оставляла magic bits в адресе класса, что приводило к вызову vtable по мусорному адресу и обнулению регистра `x22`, вызывая немедленный SIGSEGV при разыменовании `0x0`.
  2. В `CodeInputView.swift` обращение к `self.view.addSubview(self.backgroundView)` находилось прямо внутри `ASDisplayNode.init()`, вызывая форсированную синхронную инициализацию UIKit-представления до добавления узла в иерархию отображения.
  3. Жест авторизации через QR-код (`debugQrTap`) на экране ввода номера телефона был заблокирован директивой `#if DEBUG`.
- **Устранение:**
  1. В `submodules/LegacyCppCompat.mm` объявлена и экспортирована глобальная переменная `uintptr_t _objc_debug_isa_class_mask = 0x00000001fffffff8ULL`, удовлетворяющая слабый импорт `libswiftCore.dylib`.
  2. Добавлен конструктор раннего приоритета `fixup_swift_isa_mask()` (`__attribute__((constructor(101)))`), явно патчащий `_swift_isaMask` по `dlsym(RTLD_DEFAULT, "_swift_isaMask")` значением `0x00000001fffffff8ULL`.
  3. В `CodeInputView.swift` вызов `insertSubview(self.backgroundView, at: 0)` перенесён из `init()` в метод жизненного цикла `didLoad()`.
  4. В `AuthorizationSequencePhoneEntryControllerNode.swift` снята директива `#if DEBUG` с `debugQrTap` (жест по тексту подсказки) и улучшено центрирование QR-кода на узком экране 320pt.
- **Статус:** Исправлено в коммите `dae4f0b99e`. IPA собран и загружен на подключенный iPhone 5s по USB.

