# Шлюз: поиск на GitHub перед каждой фазой

Дата первого прохода: 2026-11-22 (поиск через `gh api -X GET search/repositories`). Цель: не писать с нуля то, что уже сделано хорошо и с подходящей лицензией, и не ломать замысел чужими решениями.

## Протокол шлюза (выполняет исполнитель перед первым пакетом фазы)
1. **Сформулируйте темы** фазы (колонка «Темы» ниже) и 3-6 поисковых запросов (простые слова: `godot quest`, `godot dedicated server`, без квалификаторов языка: сложные запросы возвращают пусто).
2. Выполните поиск: `gh api -X GET search/repositories -f q='godot quest' -f sort=stars -f per_page=6 --jq '.items[]|"\(.full_name)|\(.stargazers_count)|\(.license.spdx_id)|\(.pushed_at[0:10])|\(.description)"'`. Для кода: `search/code`. Лимит несколько запросов в минуту: делайте паузы.
3. **Отбор:** лицензия MIT, Apache-2.0, BSD, Unlicense, CC0 или CC-BY (GPL/AGPL/`NOASSERTION`/`none` не вносить: для них записать «отклонён, лицензия»); Godot 4.x; активность за последний год или законченная зрелая библиотека; совместимость с Godot 4.7 проверить запуском.
4. Для каждого кандидата в `docs/stages/<ФАЗА>_GITHUB_CANDIDATES.md` запишите: репозиторий, звёзды, лицензия, дата, что даёт, **решение** (внедрить, адаптировать, изучить, отклонить) и причину.
5. **Внедрение:** код кладётся в `third_party/<имя>/` с файлом лицензии и записью в `third_party/ASSETS.md`; наш код обращается к нему только через свои интерфейсы (чтобы заменить); пишутся тесты; детерминизм и серверная авторитетность (DESIGN_GUARD.md) не нарушаются.
6. **Адаптация без копирования:** если лицензия не позволяет или код тянет лишнее, берём идею и пишем своё (как сделано с godot-open-rpg).
7. Вывод по фазе кратко вносится в `docs/DECISIONS.md`.
8. Проверка безопасности: чужой код читается целиком перед включением; нет сетевых вызовов наружу, нет автообновления, нет бинарников без исходников.

## Уже оценено ранее
Кандидаты GDD-02..GDD-10: `docs/stages/GDD0x_GITHUB_CANDIDATES.md` (внедрены: godot-sqlite в планах WP-01, gdUnit4, godot-ci; изучены: godot-open-rpg, gloot, wyvernbox, godot-gameplay-abilities, effects, cervantes-tactics-godot, Lootie).

## Кандидаты и темы по фазам (найдено 2026-11-22; решения предварительные, исполнитель перепроверяет на своём шлюзе)

### Фаза 0 и 7. Основа, сеть, сервер (WP-00..WP-02, WP-70..WP-75)
| Тема | Кандидат | Лицензия | Решение |
|------|----------|----------|---------|
| CI тестов | godot-gdunit-labs/gdUnit4-action (63★, 2026-11) | MIT | внедрить в workflow (WP-00) |
| Образ CI и экспорт | barichello/godot-ci | MIT | внедрить (WP-00) |
| БД | godot-sqlite (GDExtension, клон уже изучен в /ref) | MIT | внедрить (WP-01), перепроверить лицензию и версию |
| Бэкенд социального слоя (аккаунты, чат, группы, лидерборды, матчмейкинг) | heroiclabs/nakama + nakama-godot (13.7k★/786★) | Apache-2.0 | **оценить в WP-70** как альтернативу самописным службам: если упрощает чат, друзей, лиги и хранение, брать только для социальных сервисов, бой и мир остаются на нашем авторитетном сервере |
| Эталон архитектуры MMO на Godot 4 | SlayHorizon/godot-tiny-mmo (297★, 2026-07) | MIT | изучить (структура клиент/сервер/мир), код не копировать целиком |
| Серверная авторитетность и предсказание | CodingQuests/godot-multiplayer-starter (69★) | MIT | изучить подход (валидируемые RPC, сверка), адаптировать идеи |
| Websocket-сервер с БД и аккаунтами | pixelrogueart/websocket-dedicated-server | MIT | изучить (подтверждение аккаунтов, Docker) |
| Игровой сервер на Elixir (аккаунты, лобби, друзья, чат, платежи) | appsinacup/gamend (58★, 2026-11) | MIT | изучить как возможный внешний сервис |
| Запрещено | lkuich/LemonShooterServer, Reia | AGPL | отклонить (лицензия) |
Поисковые запросы для повтора: `godot dedicated server`, `godot multiplayer rpc`, `nakama godot`, `godot websocket server`, `godot docker server`.

### Фаза 1. Бой (WP-11A..WP-15)
| Тема | Кандидат | Лицензия | Решение |
|------|----------|----------|---------|
| Сетка и перемещение TBS (A*, радиус хода) | MeshLabDev/Grid-Tactics-Foundation | MIT | изучить и адаптировать для WP-13 |
| Правила тактики, чистое ядро | Quesadius/preemptive-peril, JaiGod/iron-oath-tactics | MIT | изучить подход «чистое детерминированное ядро» (как наше) |
| Тактическая RPG-демо | ramaureirac/godot-tactical-rpg (982★) | MIT | изучить UI выбора клеток, камеру |
| Деревья поведения (мир, патрули монстров) | bitbrain/beehave (3.3k★), limbonaut/limboai (3.1k★) | MIT | LimboAI/Beehave для поведения мирового ИИ (не для боевого, он у нас кодовый детерминированный) |
| Управление ходами | BananaHolograma/turnity | MIT | изучить |
Запросы: `godot tactics`, `godot turn based`, `godot behavior tree`, `godot ability system`.

### Фаза 2. Мир (WP-20..WP-27)
| Тема | Кандидат | Лицензия | Решение |
|------|----------|----------|---------|
| Редактор карт Tiled → Godot 4 | Kiamo2/YATI (301★, 2026-10) | MIT | **адаптировать для конвейера зон WP-22**, если дизайнеры рисуют куски локаций в Tiled |
| Туман войны | TABmk/godot-4-fog-of-war | MIT | изучить для карты региона |
| Подгрузка кусков мира | edwin-cox/godot-infinite-worldmap | MIT | изучить (идея потоковой подгрузки) |
Запросы: `godot tiled`, `godot tilemap`, `godot world map`, `godot fog of war`.

### Фаза 3. Квесты (WP-30..WP-34)
| Тема | Кандидат | Лицензия | Решение |
|------|----------|----------|---------|
| Система квестов | shomykohai/quest-system (478★, 2026-08) | MIT | изучить модель целей; у нас серверная версия, берём идеи |
| Граф квестов (редактор) | TheWalruzz/godot-questify (257★) | MIT | изучить редактор как идею для инструмента авторов |
| Данные RPG (предметы, квесты, NPC как ресурсы) | bitbrain/pandora (1.1k★) | MIT | изучить для редактора данных; у нас JSON |
| Диалоги | hohfchns/DialogueQuest | MIT | изучить; наш граф диалогов уже есть в данных |
Запросы: `godot quest`, `godot dialogue`, `godot quest graph editor`.

### Фаза 4 и 5. Герои, наёмники, предметы, ремёсла, дом (WP-40..WP-56)
| Тема | Кандидат | Лицензия | Решение |
|------|----------|----------|---------|
| Инвентарь | gloot (MIT), don-tnowe/godot-wyvernbox-inventory, gamespice-platform/inventory (серверно-проверяемые операции) | MIT | изучить; у нас своя логика на сервере, берём идеи сумок и сеток |
| Характеристики и эффекты | godot-gameplay-abilities (изучено), effects | MIT | продолжить изучение для WP-11 и WP-47 |
| Крафт | поиск `godot crafting` ничего готового не дал | — | пишем сами (WP-51) |
Запросы: `godot inventory`, `godot stats`, `godot crafting`, `godot gameplay abilities`.

### Фаза 6. Подземелья (WP-60..WP-63)
Своя логика; смотреть шаблоны инстансов в godot-tiny-mmo. Запросы: `godot dungeon`, `godot instance`.

### Фаза 8 и 9. Социальное и экономика (WP-80..WP-92)
Nakama (см. выше) для чата, групп, друзей, лидербордов; аукцион и рынок пишем сами на сервере. Запросы: `godot chat`, `godot leaderboard`, `godot marketplace`.

### Фаза 10. Арт, звук, интерфейс, локализация (WP-100..WP-103)
| Тема | Кандидат | Лицензия | Решение |
|------|----------|----------|---------|
| Импорт анимаций Aseprite | viniciusgerevini/godot-aseprite-wizard (1.4k★) | MIT | внедрить, когда появятся свои анимации (WP-101) |
| Универсальные импортёры | nklbdev/godot-4-importality | MIT | запасной вариант |
| Пиксельные темы интерфейса | kitsmith-ui-themes-free (MIT), Spyridon-Pikoulas/godot-pixel-ui-* (лицензия не указана: отклонить) | MIT | изучить размеры 9-slice, взять только MIT |
| Виртуальный джойстик | Wesley-Source/versatile-mobile-joystick (MIT) | MIT | у нас свой ScreenStick; изучить идеи мультитача и безопасных зон |
| Аудио-менеджер | nathanhoad/godot_sound_manager (838★) | MIT | внедрить или адаптировать (WP-102) |
| Локализация | VP-GAMES/LocalizationEditor (86★, 2022) | MIT | изучить; в Godot 4 есть встроенные CSV/PO переводы, стандарт выбрать в WP-103 |
| Сохранение настроек | AdamKormos/SaveMadeEasy | MIT | необязательно, у нас свой |
Запросы: `godot aseprite`, `godot pixel ui theme`, `godot audio manager`, `godot localization`. Ассеты искать также на OpenGameArt и itch.io с лицензиями CC0/CC-BY (вне GitHub).

### Фаза 11. Выпуск (WP-110..WP-112)
| Тема | Кандидат | Лицензия | Решение |
|------|----------|----------|---------|
| Платежи Google Play | godot-sdk-integrations/godot-google-play-billing (268★, 2026-09), code-with-max/godot-google-play-iapp (Godot 4.7+, Billing 9.1) | MIT | внедрить один из них в WP-91, проверить на Godot 4.7.2 |
| Аналитика и краши | hastatus-games/pilum-godot (Firebase Analytics, Crashlytics, AdMob) | MIT | изучить; AdMob не использовать (политика проекта) |
| Старт мобильного проекта с ИИ | nxdinh94/godot-mobile-2d-agentic-starter | MIT | изучить структуру |
Запросы: `godot google play billing`, `godot firebase`, `godot android export`.

### Фаза 12. Расширения
Повторить шлюз по темам нового региона и режимов (WP-113..WP-116): `godot raid`, `godot capture the flag`, `godot spectator`.
