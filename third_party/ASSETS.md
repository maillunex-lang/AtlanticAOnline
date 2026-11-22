# Графика демо-версии

Все ассеты свободные (CC0, общественное достояние). Авторство указывать не обязательно, но указываем из уважения.
Графику оригинальной Atlantica Online не используем.

| Папка | Источник | Автор | Лицензия |
|-------|----------|-------|----------|
| `demo/assets/chars/` (персонажи и монстры, 18 спрайтов 16x16) | [Tiny Dungeon](https://opengameart.org/content/tiny-dungeon) | Kenney (kenney.nl) | CC0 1.0 |
| `demo/assets/tiles/` (трава, дороги, деревья, дома, указатель, 33 плитки 16x16) | [Tiny Town](https://opengameart.org/content/tiny-town) | Kenney (kenney.nl) | CC0 1.0 |
| `demo/assets/tiles/water*.png` (2 плитки воды 16x16) | [Roguelike/RPG pack](https://opengameart.org/content/roguelikerpg-pack-1700-tiles) | Kenney Vleugels, Lynn Evers (Kenney) | CC0 1.0 |

Лицензия CC0 указана в файлах License.txt наборов и на страницах OpenGameArt. Файлы скопированы без изменений
(кроме вырезки плиток воды из общего листа). Названия файлов заменены на понятные.
Спрайты персонажей в демо только временные: для релиза графику заменим на собственную или лицензированную (GDD-11).

## Интерфейс демо
| Папка | Источник | Автор | Лицензия |
|-------|----------|-------|----------|
| `demo/assets/ui/` (панели и кнопки 9-slice, масштаб x4 из плиток 16x16) | [UI Pack Pixel Adventure](https://opengameart.org/content/ui-pack-pixel-adventure) | Kenney (kenney.nl) | CC0 1.0 |
| `demo/assets/icons/` (иконки предметов, 24 шт.) | Tiny Dungeon и Tiny Town (см. выше) | Kenney | CC0 1.0 |

Иконки временные: у части предметов (ружьё, броня, шлем) нет подходящего рисунка в наборах, поэтому использованы близкие по смыслу.

## Атлас мира (редактируемый в Godot)
`demo/assets/atlas/world.png`: сборка плиток из Tiny Town и Roguelike pack (см. выше, CC0), две плитки тёмной травы получены затемнением
плитки Kenney. `shadow.png` и `ring.png` нарисованы нами. Атлас используется набором плиток `tilesets/world_tiles.tres`.

Контуры суши в `demo/assets/ui/world_coastlines.png` получены из Natural Earth 1:110m Land. Контуры растеризованы для карты, Антарктида опущена. Общественное достояние. [Данные](https://www.naturalearthdata.com/downloads/110m-physical-vectors/110m-land/) · [Условия](https://www.naturalearthdata.com/about/terms-of-use/)

## Пакеты Kimi

Комплекты [героев](../assets/heroes/PROVENANCE_KIMI_ROSTER.md), [интерфейса](../assets/ui/fantasy/PROVENANCE.md) и [мира](../assets/world/PROVENANCE.md) переданы владельцем проекта. В описании происхождения каждого комплекта указана программная генерация для Atlantic Online и отсутствие сторонних ассетов. Исходные файлы, превью и манифесты сохранены в репозитории.

`assets/world/world_atlas_64.png` объединяет тайлы Kimi с плитками зданий Kenney (CC0). `tools/compose_world_atlas.py` сохраняет координаты старых тайлов, чтобы сцены продолжали использовать прежнюю геометрию и данные проходимости. На рабочих кнопках UI заменяемые подписи рисует Godot поверх производных текстур `button_*_unlabeled.png`.

### Иллюстрации Эверхейма и Руин Стража

Пакет `stylized_fantasy_game_assets` передан владельцем. По приложенному описанию происхождения это оригинальные изображения, сгенерированные в Kimi для Atlantic Online без использования сторонней графики. Для клиента иллюстрации `port_everheim.jpg` и `whispering_forest_ruins.jpg` уменьшены до 1280×720. Каменная текстура `assets/world/arena/guardian_ruins_floor.png` адаптирована до 128×128 и используется в боях Руин Стража. [Исходный пакет](https://drive.google.com/file/d/11Om4XA-ytVdF69fgRX0oMIhGfROhoJVa/view)
