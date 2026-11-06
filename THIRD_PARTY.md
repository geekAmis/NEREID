# Сторонние ассеты и лицензии

Проект использует только CC0, OFL и собственные материалы. Ниже — полный
список с указанием источника, лицензии и автора.

---

## Движок

| Компонент | Версия | Лицензия | Источник |
|---|---|---|---|
| Godot Engine | 4.7.2 stable | MIT | https://godotengine.org |

Godot не распространяется вместе с исходниками игры; для запуска используется
установленный редактор/рантайм.

---

## PBR-текстуры

Все текстуры — **CC0 1.0 Universal**, автор **ambientCG** (https://ambientcg.com).
Скачаны через `assetfinder` и сохранены в `game/assets/textures/`.

| Набор | Использование | Файлы |
|---|---|---|
| PaintedMetal016 | внутренняя обшивка, панели | Color, NormalGL, Roughness, Metalness, AO |
| MetalPlates006 | пол, настил, люки | Color, NormalGL, Roughness, Metalness |
| Metal063 | ржавые кромки, трубы | Color, NormalGL, Roughness |
| Concrete046 | внешний купол, бетон | Color, NormalGL, Roughness |
| Rubber004 | уплотнители, кабели | Color, NormalGL, Roughness |
| Leather037 | кресло, ремни | Color, NormalGL, Roughness |

Манифест загрузок: `_assets_raw/manifest.jsonl` (не входит в релиз, но
сохранён локально для аудита).

---

## Шрифты

| Шрифт | Лицензия | Источник |
|---|---|---|
| PT Sans | SIL Open Font License 1.1 | https://fonts.google.com/specimen/PT+Sans |
| JetBrains Mono | SIL Open Font License 1.1 | https://www.jetbrains.com/lp/mono/ |
| Caveat | SIL Open Font License 1.1 | https://fonts.google.com/specimen/Caveat |

Шрифты используются для интерфейса, шкал и рукописного блокнота.

---

## Звук

| Источник | Лицензия | Примечание |
|---|---|---|
| Процедурный синтез `AudioSynth` | собственность проекта | генерируется в рантайме |
| SAPI Microsoft Irina (ru-RU) | локальная лицензия Windows | только сгенерированные WAV в `game/assets/voice/` |
| Тишина, шумы, дроны | собственность проекта | синтез |

Никакие сторонние музыкальные треки не используются.

---

## Софт для разработки

| Инструмент | Лицензия | Использование |
|---|---|---|
| assetfinder | MIT | поиск и скачивание CC0-ассетов |
| Git for Windows | GPLv2 | версионный контроль |
| Python 3.13 | PSF | генерация озвучки, скрипты |
| Pillow | HPND | анализ текстур |

---

## Что нельзя делать

- Продавать или распространять текстуры ambientCG отдельно от игры (CC0
  этого не запрещает, но это неэтично по отношению к автору).
- Использовать голос Microsoft Irina вне сгенерированных WAV без лицензии.
- Удалять этот файл при распространении билда.

---

## Атрибуция в игре

В титрах:

> PBR textures: ambientCG (CC0)
> Fonts: PT Sans, JetBrains Mono, Caveat (OFL)
> Engine: Godot 4.7.2 (MIT)
> Voice: locally generated SAPI (Microsoft Irina)

---

*Обновлено: 06.11.2026.*
