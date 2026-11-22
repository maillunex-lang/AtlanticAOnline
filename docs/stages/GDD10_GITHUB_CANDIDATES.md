# GDD-10 UI/UX (горизонтальный режим): кандидаты с GitHub

Статус: **утверждено 2026-11-22** по рекомендациям. Дата поиска: 2026-11-22.

## Главный вывод поиска
Готовых игровых интерфейсов под нашу серверную логику на GitHub нет, а темы пиксельного UI для Godot либо без определённой
лицензии, либо слишком новые и малоизвестные. Лучший вариант нашёлся вне GitHub: набор Kenney UI Pack Pixel Adventure (CC0)
на OpenGameArt в том же стиле, что и уже утверждённая графика. Экраны пишем сами поверх готовой игровой логики.

## Внедрено
| Что | Источник | Лицензия |
|-----|----------|----------|
| Панели и кнопки 9-slice | [UI Pack Pixel Adventure](https://opengameart.org/content/ui-pack-pixel-adventure) (Kenney) | CC0 |
| Иконки предметов | Tiny Dungeon, Tiny Town (Kenney) | CC0 |

## Изучено, не внедрено
| Репозиторий | Лицензия | Почему не берём |
|-------------|----------|-----------------|
| [Wesley-Source/versatile-mobile-joystick](https://github.com/Wesley-Source/versatile-mobile-joystick) ★26 | MIT | Начиная с Godot 4.7 в движке есть собственный узел `VirtualJoystick`. Нам хватило короткого своего джойстика (`ScreenStick`), зависимостей нет |
| [JoenTNT/godot_thumbstick_addon](https://github.com/JoenTNT/godot_thumbstick_addon) ★20 | MIT | То же |
| [peter-kish/gloot](https://github.com/peter-kish/gloot) | MIT | Инвентарь на узлах, наш инвентарь живёт на сервере. Идеи сетки слотов учтены |
| Spyridon-Pikoulas/godot-pixel-ui-free и родственные | не определена (NOASSERTION) | Лицензия не позволяет брать |
| [CodingQuests/godot-inventory-system](https://github.com/CodingQuests/godot-inventory-system) | MIT | Очень новый, 0 звёзд, не нужен |

## Не нужно
Темы для визуальных новелл и сторонних UI-китов (shadcn-стиль и подобные): не в стиле игры.
