# TOOLCHAIN.md — Тулчейн и сборка

## Среда сборки
- **macOS:** Darwin arm64 (macOS 15+)
- **Xcode:** 16.x / 26.x (`xcodebuild -version`)
- **Bazel:** 8.2.1 (автоматически скачивается через `build-system/Make/BazelLocation.py`)
- **Базовая ветка:** `release-11.12` (ветка `legacy-ios10`)

## Статус Deployment Target (Проверено 2026-10-28)
- Исходная минимальная ОС в `Telegram/BUILD`: `12.0`.
- **Результат тестирования компилятора:**
  - `clang -target arm64-apple-ios10.3`: успешно собирает объектные файлы с `cmd LC_VERSION_MIN_IPHONEOS version 10.3`.
  - `swiftc -target arm64-apple-ios10.3`: успешно собирает Swift-модули без ошибок и сохраняет рантайм-проверки `#available(iOS 11.0, *)`.
  - **Вывод:** Патчинг Mach-O заголовков не требуется; тулчейн корректно поддерживает целевую ОС 10.3 напрямую.
