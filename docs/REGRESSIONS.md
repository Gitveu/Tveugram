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
