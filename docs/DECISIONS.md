# DECISIONS.md — Архитектурные решения и компромиссы

## Формат записей
Каждая запись содержит дату, контекст, принятое решение и обоснование.

---

### [2026-10-28] Выбор базовой версии для форка: release-11.12
- **Контекст:** Необходим баланс между современным набором фич и объёмом бэкпорта на iOS 10.3.3.
- **Решение:** Выбрана `release-11.12`.
- **Обоснование:** Последняя стабильная версия до поднятия min OS до iOS 13.0. Отсутствует Liquid Glass, кодовая база содержит классический UI и максимальный набор апстрим-фич (истории, топики, папки, реакции, подарки/звёзды).

---

### [2026-10-28] Архитектура Local Premium (§8)
- **Контекст:** Требуется разблокировать клиентские премиум-возможности (смена иконки, повышенные лимиты аккаунтов, папок, закреплений, бейдж) без реальной серверной подписки.
- **Решение:** Создан централизованный модуль `LocalPremium` в `TelegramCore` с хранением флага в `UserDefaults` (дефолт `true`). В MTProto-парсере `TelegramUser.swift` для текущего пользователя (`flags & (1 << 10) != 0`, `isSelf`) автоматически выставляется флаг `.isPremium`. Для внешних проверок задействован `LocalPremium.override(_:)`. В `DebugController` добавлен тумблер выключения.
- **Обоснование:** Такой подход гарантирует, что чужие пользователи отображают свой реальный статус (не превращаются в премиум), а текущий аккаунт прозрачно получает доступ ко всем клиентским фичам без размазанных хаков по экранам.

---

### [2026-10-28] Модернизация MTProto TLS handshake (P0 Login)
- **Контекст:** В `release-11.12` отпечаток `ClientHello` в `MTTcpConnection.m` содержал статические заголовки, блокируемые серверами Telegram MTProto при логине.
- **Решение:** Перенесен современный механизм формирования TLS handshake из апстрима (`3d6fabea330b3e44ed986154ccbda29748403b27`) с динамической поддержкой ML-KEM, Grease-значений и рандомизированных расширений.

---

### [2026-10-28] Кодирование видео-сообщений (кружков) на iOS 10 (P0)
- **Контекст:** На iOS 10 отсутствуют символы `AVVideoCodecTypeH264` и поддержка HEVC, а также метод `NSKeyedArchiver.archivedData(withRootObject:requiringSecureCoding:)`.
- **Решение:** В кодовых путях записи и сжатия видео (`TGMediaVideoConverter.m`, `CameraOutput.swift`, `MediaEditorValues.swift`) принудительно активирован H.264 с литералом `@"avc1"` на iOS 10. В сериализации настроек кружка добавлен фолбэк на `NSKeyedArchiver.archivedData(withRootObject:)`.

---

### [2026-10-29] Адаптация Swift-протоколов и экспорт символов для сборки Simulator (x86_64) и iOS 10.3
- **Контекст:** При компиляции с deployment target 10.3 на Xcode 16.2 / SDK 26.5 классы, напрямую объявляющие конформанс протоколам iOS 11+ (`UIDropInteractionDelegate`, `UIPencilInteractionDelegate`, `ASAuthorizationControllerDelegate`), вызывают ошибку компилятора, требующего доступность методов протокола на iOS 10.3. Кроме того, при WMO-компиляции `TelegramCore` linker dead-stripping удалял невызванные внутри модуля объектные файлы (`AppConfiguration.swift.o`), приводя к undefined symbols в `TelegramUIFramework`.
- **Решение:** 
  1. Конформансы к протоколам iOS 11+ вынесены в `@available(iOS 11.0, *)` (или `13.0`) extensions (`DrawingScreen`, `DrawingView`, `MediaEditorScreenImpl`, `ChatControllerImpl`, `PrivacyAndSecurityControllerImpl`, `AuthorizationSequenceController`).
  2. В `TelegramCoreFramework` добавлен linker flag `-all_load` для гарантированного экспорта всех публичных Swift-символов из статического архива `libTelegramCore.a`.
  3. Для `dav1d` под `x86_64` отключен ассемблер (`-Denable_asm=false`), `td` настроен на x86_64, а `rules_apple` пропатчен для игнорирования истёкших fake provisioning profiles.
