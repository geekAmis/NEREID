# Contributing to NEREID

Спасибо, что хотите помочь. Проект небольшой, но правила простые.

## Ветки

| Ветка | Назначение |
|---|---|
| `main` | стабильные релизы, только merge из `develop` |
| `develop` | интеграция текущей версии |
| `feature/<id>-<slug>` | новая функциональность |
| `fix/<id>-<slug>` | исправления |
| `docs/<slug>` | документация и медиа |

Один issue — одна ветка — один merge. Коммиты:

```text
type(scope): summary

Refs #123
```

`type`: `feat`, `fix`, `docs`, `test`, `build`, `perf`, `chore`.

## Перед PR

```bash
godot --headless --path game --import
godot --headless --path game --script res://tests/run_tests.gd
```

Ожидается `PASS: 101 checks`. Если добавляете механику — добавьте проверку в `game/tests/run_tests.gd`.

## Код

- Godot 4.7.2, Forward+, **typed GDScript**.
- Отступы — табы, как в существующих файлах.
- Новые системы — `RefCounted`, без зависимости от сцены; сцена только связывает.
- Никаких плагинов и внешних зависимостей в рантайме.
- Все строки интерфейса — через `Loc`/JSON, не хардкод в сцене.
- Звук — через `AudioDirector` и шины, не `AudioStreamPlayer` напрямую.

## Ассеты

- Только **CC0** или **OFL**; добавляйте запись в `THIRD_PARTY.md`.
- Текстуры — в `game/assets/textures/<set>/` с `color/normal/roughness`.
- Голос — в `game/assets/voice/<id>.wav`, 22.05 кГц mono, генерируется `tools/generate_voice.ps1`.
- Не коммитьте `_assets_raw/`, `_frames/`, `_shots/`, `build/`, `game/.godot/`.

## Релиз

1. Обновить `CHANGELOG.md` и `.docs/TODO.JSON`.
2. Прогнать тесты.
3. `tools/export_win.cmd`.
4. Собрать `build/NEREID-<version>-win64.zip` (exe + README + LICENSE + THIRD_PARTY).
5. Тег `v<version>` и GitHub Release.

## Стиль общения

- Баги — с логом, шагами и версией.
- Предложения — с критериями приёмки.
- Не публикуйте чужие ассеты и голоса без лицензии.
