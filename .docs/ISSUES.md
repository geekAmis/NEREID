# NEREID — issue-трекер

> Синхронизирован с GitHub Issues: https://github.com/geekAmis/NEREID/issues
> Локальная копия ведётся для офлайна и ревью. Формат совместим с GitHub Issues:
> ID, тип, приоритет, статус, ветка, коммиты, критерии.

**Легенда статусов:** `OPEN` · `IN PROGRESS` · `DONE` · `WONTFIX`
**Типы:** `feature` · `bug` · `tech` · `art` · `audio` · `narrative` · `docs` · `perf`

---

## Сводка

| Метрика | Значение |
|---|---|
| Всего issue | 24 |
| DONE | 15 |
| IN PROGRESS | 2 |
| OPEN | 7 |
| WONTFIX | 0 |

### GitHub Issues

| GitHub | Локальный | Статус |
|---|---|---|
| [#1](https://github.com/geekAmis/NEREID/issues/1) | NER-115 · k-NN | OPEN |
| [#2](https://github.com/geekAmis/NEREID/issues/2) | NER-120 · бобины | OPEN |
| [#3](https://github.com/geekAmis/NEREID/issues/3) | NER-113 · финалы | OPEN |
| [#4](https://github.com/geekAmis/NEREID/issues/4) | NER-122 · EN | OPEN |
| [#5](https://github.com/geekAmis/NEREID/issues/5) | NER-114 · perf | OPEN |
| [#6](https://github.com/geekAmis/NEREID/issues/6) | NER-121 · геймпад | OPEN |
| [#7](https://github.com/geekAmis/NEREID/issues/7) | NER-123 · актриса | OPEN |
| [#8](https://github.com/geekAmis/NEREID/issues/8) | NER-124 · Ollama | OPEN |
| [#9](https://github.com/geekAmis/NEREID/issues/9) | NER-119 · Steam | OPEN |
| [#10](https://github.com/geekAmis/NEREID/issues/10) | NER-008 · товарный знак | OPEN |
| [#11](https://github.com/geekAmis/NEREID/issues/11) | Release v0.1.0 | DONE |

---

## NER-101 · feature · P0 · DONE

**Каркас проекта и автолоады**

Ветка: `feature/101-project-skeleton`
Коммиты: `feat(core): project skeleton, autoloads, input map`
Критерии: проект открывается в Godot 4.7.2, меню ↔ игра, настройки в `user://`.

---

## NER-102 · feature · P0 · DONE

**Процедурная кабина и материалы**

Ветка: `feature/102-cabin`
Коммиты: `feat(cabin): procedural hull, PBR materials, lighting`
Критерии: сфера с иллюминатором, 6 материалов, 6 источников света, 60 fps.

---

## NER-103 · feature · P0 · DONE

**CapsuleSim: все системы**

Ветка: `feature/103-simulation`
Коммиты: `feat(sim): oxygen, co2, power, water, hull, depth, cable, noise, stress`
Критерии: 10 000 тиков, инварианты, сериализация.

---

## NER-104 · feature · P0 · DONE

**24 интерактивных устройства**

Ветка: `feature/104-devices`
Коммиты: `feat(cabin): interactables, switches, knobs, winch, scrubber, radio`
Критерии: каждое устройство анимировано, звучит, влияет на симуляцию.

---

## NER-105 · feature · P0 · DONE

**Гидрофон, CRT, каталог сигналов**

Ветка: `feature/105-hydrophone`
Коммиты: `feat(audio): hydrophone, CRT spectrum, signal catalog`
Критерии: 10 сигналов, реальный DFT, пинг, идентификация.

---

## NER-106 · feature · P0 · DONE

**Фотоаппарат и слой аномалий**

Ветка: `feature/106-photo`
Коммиты: `feat(fx): camera, flash, viewport capture, anomaly layer, board`
Критерии: 12 кадров, PNG, проявка, на снимке есть скрытое.

---

## NER-107 · feature · P0 · DONE

**Silence Director и Listener**

Ветка: `feature/107-ai`
Коммиты: `feat(ai): silence director, listener fsm, noise attention`
Критерии: темп, cooldown, тишина снижает внимание, удар не убивает.

---

## NER-108 · feature · P0 · DONE

**3 акта, 6 задач, 2 финала**

Ветка: `feature/108-narrative`
Коммиты: `feat(narrative): acts, tasks, radio, tapes, endings surface/answer`
Критерии: 20-минутный срез играется от начала до финала.

---

## NER-109 · feature · P1 · DONE

**Меню, пауза, настройки, сейвы**

Ветка: `feature/109-ui`
Коммиты: `feat(ui): menu, pause, settings, save/load, accessibility`
Критерии: настройки сохраняются, сейв/лоад, субтитры.

---

## NER-110 · tech · P0 · DONE

**Headless-тесты и валидация**

Ветка: `feature/110-tests`
Коммиты: `test(sim): invariants, director, listener, save round-trip`
Критерии: `--script res://tests/run_tests.gd` → 0, отчёт.

---

## NER-111 · art · P0 · DONE

**Постобработка и шейдеры**

Ветка: `feature/111-postfx`
Коммиты: `feat(fx): grain, vignette, aberration, glass, water, CRT shaders`
Критерии: один pass, настройки, без артефактов.

---

## NER-112 · audio · P0 · DONE

**Процедурный звук и SAPI-озвучка**

Ветка: `feature/112-audio`
Коммиты: `feat(audio): synth, buses, voice lines, adaptive mix`
Критерии: 30+ клипов, 28 реплик, радио-фильтр.

---

## NER-113 · narrative · P0 · IN PROGRESS

**Финалы «Тишина» и «Хранитель»**

Ветка: `feature/113-endings`
Критерии: активный выбор, уникальные сцены, 4/4 финала.
Статус: сценарий готов, реализация после демо.

---

## NER-114 · perf · P0 · IN PROGRESS

**Профилирование на GTX 1060**

Ветка: `feature/114-performance`
Критерии: 60 fps, 3 quality preset, бюджет draw calls.
Статус: замеры на целевой машине, оптимизация мелких мешей.

---

## NER-115 · ai · P1 · OPEN

**k-NN-классификатор сигналов**

Ветка: `feature/115-knn`
Критерии: 10 классов, точность ≥85 %, 2 гипотезы, офлайн.

---

## NER-116 · tech · P1 · DONE

**Экспортный билд**

Ветка: `feature/116-export`
Коммиты: `build(win64): export templates, embedded pck, NEREID.exe`
Критерии: шаблоны 4.7.2 установлены, `--export-release`, билд запускается без редактора. Выполнено: `build/NEREID.exe` (встроенный PCK).

---

## NER-117 · marketing · P1 · DONE

**GitHub Release, трейлер и скриншоты**

Ветка: `feature/117-media`
Коммиты: `docs(media): screenshots, 19s trailer, release page`
Критерии: 6 скриншотов, GIF/WebP/MP4-трейлер, README с медиа, тег `v0.1.0-vertical-slice`.

---

## NER-118 · docs · P2 · DONE

**Импорт issues на GitHub**

Ветка: `feature/118-issue-import`
Коммиты: `docs(issues): sync local tracker with GitHub`
Критерии: issues созданы через GitHub API, локальный трекер совпадает по ID и статусам.

---

## NER-119 · marketing · P1 · OPEN

**Steam-страница и Next Fest**

Ветка: `feature/119-steam`
Критерии: капсула, 6 скриншотов, 45-секундный трейлер, 15 тегов, демо для Next Fest.

---

## NER-120 · audio · P2 · OPEN

**Запись на бобины и переслушивание**

Ветка: `feature/120-tape-recorder`
Критерии: 3 бобины по 30 с, фильтры, расходник, воспроизведение в кабине.

---

## NER-121 · tech · P2 · OPEN

**Геймпад и Steam Deck**

Ветка: `feature/121-gamepad`
Критерии: полный маппинг, подсказки, 40+ fps на Deck (Proton), шрифты читаемы.

---

## NER-122 · docs · P1 · OPEN

**Полная английская локализация**

Ветка: `feature/122-en`
Критерии: все меню, HUD, субтитры и ленты на EN; переключение без перезапуска.

---

## NER-123 · audio · P2 · OPEN

**Профессиональная актриса на Веру**

Ветка: `feature/123-vera-voice`
Критерии: 32 реплики, 48 кГц, радио-обработка, синхронизация с субтитрами.

---

## NER-124 · ai · P2 · OPEN

**Опциональное LLM-радио (Ollama)**

Ветка: `feature/124-ollama`
Критерии: выключено по умолчанию, таймаут, fallback, без сети.

---

## Правила ведения

1. Один issue — одна ветка — один PR/merge.
2. Commit message: `type(scope): summary` + `Refs #NNN`.
3. Закрытие issue — только после критериев и теста.
4. Критические баги (`bug`, P0) — отдельная ветка `fix/`.
5. Раз в неделю — ревизия: `DONE` → архив, `OPEN` → приоритизация.

---

## Архив (DONE)

- NER-101…112 — вертикальный срез.
- NER-113 — сценарии финалов (реализация в v0.2).
- NER-116 — Windows-билд.
- NER-117 — трейлер, скриншоты, GitHub Release.
- NER-118 — синхронизация issues.
