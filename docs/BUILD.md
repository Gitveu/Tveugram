# BUILD.md — Отпечатки сборок и инструкции

## Базовые команды сборки

### 1. Полная сборка приложения (IPA / App Bundle)
```bash
python3 build-system/Make/Make.py --overrideXcodeVersion build \
    --configurationPath=build-config.json \
    --codesigningInformationPath=build-system/fake-codesigning \
    --buildNumber=100001 \
    --configuration=release_arm64
```

### 2. Сборка целевых модулей (для верификации)
```bash
python3 build-system/Make/Make.py --overrideXcodeVersion build \
    --configurationPath=build-config.json \
    --codesigningInformationPath=build-system/fake-codesigning \
    --buildNumber=100001 \
    --configuration=release_arm64 \
    --target=//submodules/TelegramCore:TelegramCore
```

---

## История сборок
| Дата | Ревизия | Тулчейн | Конфигурация | Результат | Примечания |
|---|---|---|---|---|---|
| 2026-10-28 | `legacy-ios10` | Bazel 8.2.1, Xcode 16.x (26.6 SDK) | release_arm64 | Успешно (TelegramCore) | `libTelegramCore.a` собран под arm64/iOS 10.3 с `LocalPremium` и новым TLS ClientHello |
| 2026-10-28 | `legacy-ios10` | Bazel 8.2.1, Xcode 16.x (26.6 SDK) | release_arm64 | P0 аудит завершен | 114 файлов пропатчены: maskedCorners, contentInsetAdjustmentBehavior, кружки, H.264 |
