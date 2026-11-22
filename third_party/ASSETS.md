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
