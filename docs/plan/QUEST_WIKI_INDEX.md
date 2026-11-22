# Реестр квестов по вики

Снимок категорий от 22 ноября 2026 года. Названия ниже идентифицируют источники для проектирования. Игровые задания пишем для собственного мира.

Основной сюжет определяется таблицей **Main Quest Chains**. Общая категория включает и другие типы страниц. В реестре каждая страница указана один раз по заголовку MediaWiki. Для пересечений перечислены все категории. NPC и служебные страницы сохранены. Строка в таблице или страница категории может описывать несколько заданий.

## Сбор категорий

| Категория | Страниц | Страниц на каждой странице списка |
|---|---:|---|
| [Общая](https://rikagro.ru/wiki/Category:Quests) | 258 | 200 + 58 |
| [Ежедневные](https://rikagro.ru/wiki/Category:Daily_Quests) | 19 | 19 |
| [Найм](https://rikagro.ru/wiki/Category:Mercenary_recruitment_quest_chains) | 35 | 35 |

В трёх категориях 312 записей. После объединения 51 повторения осталось **261 уникальная страница**.

## Основной сюжет

[Таблица вики](https://rikagro.ru/wiki/Quest_Chain#Main_Quest_Chains)

В таблице 17 строк. В реестре найдены 15 страниц. У 2 строк ссылки ведут на отсутствующие страницы.

| Слот | Уровень в вики | Источник | В реестре | Соответствие в игре |
|---|---:|---|---|---|
| main_01 | 1 | [Forest of Spirits](<https://rikagro.ru/wiki/Forest_of_Spirits_(Quest)>) | Да | Путь из порта |
| main_02 | 11 | Ruins of the Yellow River | Страница отсутствует | Хранитель и маяки |
| main_03 | 16 | [Sea Palace](<https://rikagro.ru/wiki/Sea_Palace_(Quest)>) | Да | Огни Рассвета |
| main_04 | 24 | [Angkor Wat](<https://rikagro.ru/wiki/Angkor_Wat_(Quest)>) | Да | Запланировано (WP-32) |
| main_05 | 32 | [Nest of Insects](<https://rikagro.ru/wiki/Nest_of_Insects_(Quest)>) | Да | Запланировано (WP-32) |
| main_06 | 40 | [Mohenjodaro](<https://rikagro.ru/wiki/Mohenjodaro_(Quest)>) | Да | Запланировано (WP-32) |
| main_07 | 48 | [Bran Castle](<https://rikagro.ru/wiki/Bran_Castle_(Quest)>) | Да | Запланировано (WP-32) |
| main_08 | 54 | [Cretan Labyrinth](<https://rikagro.ru/wiki/Cretan_Labyrinth_(Quest)>) | Да | Запланировано (WP-32) |
| main_09 | 59 | [Hanging Gardens](<https://rikagro.ru/wiki/Hanging_Gardens_(Quest)>) | Да | Запланировано (WP-32) |
| main_10 | 67 | [Valley of the Kings](<https://rikagro.ru/wiki/Valley_of_the_Kings_(Quest)>) | Да | Запланировано (WP-32) |
| main_11 | 75 | [Sunken Machine Shrine](<https://rikagro.ru/wiki/Sunken_Machine_Shrine_(Quest)>) | Да | Запланировано (WP-32) |
| main_12 | 80 | [Shogun Castle of Death](<https://rikagro.ru/wiki/Shogun_Castle_of_Death_(Quest)>) | Да | Запланировано (WP-32) |
| main_13 | 80 | Key | Страница отсутствует | Запланировано (WP-32) |
| main_14 | 90 | [Lost Volcano Valley](<https://rikagro.ru/wiki/Lost_Volcano_Valley_(Quest)>) | Да | Запланировано (WP-32) |
| main_15 | 95 | [Yggdrasil](<https://rikagro.ru/wiki/Yggdrasil_(Quest)>) | Да | Запланировано (WP-32) |
| main_16 | 96 | [Constantinople Battlefield](<https://rikagro.ru/wiki/Constantinople_Battlefield_(Quest)>) | Да | Запланировано (WP-32) |
| main_17 | 136 | [Katherine at Katherine Gorge](<https://rikagro.ru/wiki/Katherine_at_Katherine_Gorge_(Quest)>) | Да | Запланировано (WP-32) |

## Обучение

[Beginner Tutorial (Scion)](https://rikagro.ru/wiki/Beginner_Tutorial_(Scion)) начинается после создания персонажа. В вики девять этапов. Они охватывают следование указателю, применение ключа, первые бои, найм бойцов и переход в стартовую зону.

В игре доступна дополнительная трёхшаговая цепочка «Обучение в Эверхейме». Она знакомит с перемещением, вербовщицей, кузнецом и первым боем. Практику применения ключа и найма в самой учебной цепочке ещё предстоит добавить.

## Шаги внутри страниц

[Таблица этапов (CSV)](QUEST_WIKI_STEPS.csv) содержит 46 строк из четырёх сохранённых страниц. [Статус разбора (CSV)](QUEST_WIKI_STEP_COVERAGE.csv) охватывает все 261 страницу реестра.

| Источник | Этапы |
|---|---:|
| [Beginner Tutorial (Scion)](https://rikagro.ru/wiki/Beginner_Tutorial_(Scion)#Quest_Details) | 9 |
| [Forest of Spirits](https://rikagro.ru/wiki/Forest_of_Spirits_(Quest)#Quest_Details) | 22 |
| [Monk Recruitment](https://rikagro.ru/wiki/Monk_Recruitment_(Quest)#Quests) | 10 |
| [Best Jewels](https://rikagro.ru/wiki/Best_Jewels_(Quest)#Quest_Details) | 5 |

Позиция сохраняет порядок строк источника. Для Best Jewels вики прямо разрешает любой порядок. Если уровень указан для цепочки, это отмечено в отдельной колонке. Условие открытия приводится при наличии в источнике. Строки переходов в Forest of Spirits сохранены в примечаниях, а строка с итоговой суммой в Monk Recruitment исключена из подсчёта шагов.

Повторные запросы к вики вернули HTTP 503. Для разбора использованы ранее сохранённые HTML-страницы. В сохранённой версии Avalon таблицы нет. Загрузка и разбор остальных 256 страниц ожидаются.

## Единый список страниц

| Страница | Категории |
|---|---|
| [A Tense Moment (Quest)](<https://rikagro.ru/wiki/A_Tense_Moment_(Quest)>) | Общая, Найм |
| [About Towns (quest)](<https://rikagro.ru/wiki/About_Towns_(quest)>) | Общая |
| [Airship Trade (Quest)](<https://rikagro.ru/wiki/Airship_Trade_(Quest)>) | Общая |
| [Alishan Mountain (Quest)](<https://rikagro.ru/wiki/Alishan_Mountain_(Quest)>) | Общая |
| [An Acong's Request (Quest)](<https://rikagro.ru/wiki/An_Acong's_Request_(Quest)>) | Общая |
| [Angkor Wat (Quest)](<https://rikagro.ru/wiki/Angkor_Wat_(Quest)>) | Общая |
| [Animal Researcher (Quest)](<https://rikagro.ru/wiki/Animal_Researcher_(Quest)>) | Общая |
| [AoA isn't as difficult as it seems! (Quest)](<https://rikagro.ru/wiki/AoA_isn't_as_difficult_as_it_seems%21_(Quest)>) | Общая |
| [Ariana](<https://rikagro.ru/wiki/Ariana>) | Общая |
| [Athena's Blessing (Quest)](<https://rikagro.ru/wiki/Athena's_Blessing_(Quest)>) | Общая |
| [Atlantis (Quest)](<https://rikagro.ru/wiki/Atlantis_(Quest)>) | Общая |
| [Avalon (Quest)](<https://rikagro.ru/wiki/Avalon_(Quest)>) | Общая |
| [Bandit Clearing (Quest)](<https://rikagro.ru/wiki/Bandit_Clearing_(Quest)>) | Общая |
| [Bao Sanning, the Supplier (quest)](<https://rikagro.ru/wiki/Bao_Sanning%2C_the_Supplier_(quest)>) | Общая |
| [Basic Training (Quest)](<https://rikagro.ru/wiki/Basic_Training_(Quest)>) | Общая |
| [Battle of Red Cliff (Quest)](<https://rikagro.ru/wiki/Battle_of_Red_Cliff_(Quest)>) | Общая |
| [Beast Trainer Recruitment (Quest)](<https://rikagro.ru/wiki/Beast_Trainer_Recruitment_(Quest)>) | Найм |
| [Beginner Tutorial (Scion)](<https://rikagro.ru/wiki/Beginner_Tutorial_(Scion)>) | Общая |
| [Best Jewels (Quest)](<https://rikagro.ru/wiki/Best_Jewels_(Quest)>) | Общая, Ежедневные |
| [Blue Guardian (Quest)](<https://rikagro.ru/wiki/Blue_Guardian_(Quest)>) | Общая |
| [Boatman's Daughter (Quest)](<https://rikagro.ru/wiki/Boatman's_Daughter_(Quest)>) | Общая |
| [Boorchu](<https://rikagro.ru/wiki/Boorchu>) | Общая |
| [Bran Castle (Quest)](<https://rikagro.ru/wiki/Bran_Castle_(Quest)>) | Общая |
| [Byzantium Ruins (Quest)](<https://rikagro.ru/wiki/Byzantium_Ruins_(Quest)>) | Общая |
| [Cacao Fruit](<https://rikagro.ru/wiki/Cacao_Fruit>) | Общая |
| [Cannoneer Recruitment (Quest)](<https://rikagro.ru/wiki/Cannoneer_Recruitment_(Quest)>) | Общая, Найм |
| [Centaur Hero (Quest)](<https://rikagro.ru/wiki/Centaur_Hero_(Quest)>) | Общая, Найм |
| [Centaur Village (Quest)](<https://rikagro.ru/wiki/Centaur_Village_(Quest)>) | Общая |
| [Champion Recruitment (Quest)](<https://rikagro.ru/wiki/Champion_Recruitment_(Quest)>) | Общая, Найм |
| [Chang An's Watchman (Quest)](<https://rikagro.ru/wiki/Chang_An's_Watchman_(Quest)>) | Общая, Ежедневные |
| [Chaos at the Yellow River (Quest)](<https://rikagro.ru/wiki/Chaos_at_the_Yellow_River_(Quest)>) | Общая |
| [Ching Yue](<https://rikagro.ru/wiki/Ching_Yue>) | Общая |
| [Christmas Event (quest chain)](<https://rikagro.ru/wiki/Christmas_Event_(quest_chain)>) | Общая |
| [Cleaning the Art Gallery! (Quest)](<https://rikagro.ru/wiki/Cleaning_the_Art_Gallery%21_(Quest)>) | Общая |
| [Coarse Materials (quest)](<https://rikagro.ru/wiki/Coarse_Materials_(quest)>) | Общая |
| [Collecting War Supplies 1 (quest)](<https://rikagro.ru/wiki/Collecting_War_Supplies_1_(quest)>) | Общая |
| [Collecting War Supplies 2 (quest)](<https://rikagro.ru/wiki/Collecting_War_Supplies_2_(quest)>) | Общая |
| [Collecting War Supplies 3 (quest)](<https://rikagro.ru/wiki/Collecting_War_Supplies_3_(quest)>) | Общая |
| [Coming to an End (quest)](<https://rikagro.ru/wiki/Coming_to_an_End_(quest)>) | Общая |
| [Community (Quest)](<https://rikagro.ru/wiki/Community_(Quest)>) | Общая |
| [Competition (Quest)](<https://rikagro.ru/wiki/Competition_(Quest)>) | Общая |
| [Comrade Emblem](<https://rikagro.ru/wiki/Comrade_Emblem>) | Общая |
| [Constantinople Battlefield (Quest)](<https://rikagro.ru/wiki/Constantinople_Battlefield_(Quest)>) | Общая |
| [Contaminated Nest (Quest)](<https://rikagro.ru/wiki/Contaminated_Nest_(Quest)>) | Общая |
| [Contaminated Papyrus (Quest)](<https://rikagro.ru/wiki/Contaminated_Papyrus_(Quest)>) | Общая |
| [Converting Mercenaries (Quest)](<https://rikagro.ru/wiki/Converting_Mercenaries_(Quest)>) | Общая |
| [Cretan Labyrinth (Quest)](<https://rikagro.ru/wiki/Cretan_Labyrinth_(Quest)>) | Общая |
| [Curious Scientist (Quest)](<https://rikagro.ru/wiki/Curious_Scientist_(Quest)>) | Общая |
| [Dallas Lawless District (Quest)](<https://rikagro.ru/wiki/Dallas_Lawless_District_(Quest)>) | Общая |
| [Dark Harpies' Claws (quest)](<https://rikagro.ru/wiki/Dark_Harpies'_Claws_(quest)>) | Общая |
| [Death's Boundary (Quest)](<https://rikagro.ru/wiki/Death's_Boundary_(Quest)>) | Общая |
| [Decorate My Home (Quest)](<https://rikagro.ru/wiki/Decorate_My_Home_(Quest)>) | Общая |
| [Deserted Hall (Quest)](<https://rikagro.ru/wiki/Deserted_Hall_(Quest)>) | Общая |
| [Destiny of Marduk (Quest)](<https://rikagro.ru/wiki/Destiny_of_Marduk_(Quest)>) | Общая |
| [Diabolic Entrance Exam (Quest)](<https://rikagro.ru/wiki/Diabolic_Entrance_Exam_(Quest)>) | Общая |
| [Diabolic Legion Quests](<https://rikagro.ru/wiki/Diabolic_Legion_Quests>) | Общая |
| [Dignified Viking 2 (quest)](<https://rikagro.ru/wiki/Dignified_Viking_2_(quest)>) | Общая |
| [Dimension Strider (Quest)](<https://rikagro.ru/wiki/Dimension_Strider_(Quest)>) | Общая |
| [Dimension Strider's Request (Quest)](<https://rikagro.ru/wiki/Dimension_Strider's_Request_(Quest)>) | Общая |
| [Dinosaur Master (Quest)](<https://rikagro.ru/wiki/Dinosaur_Master_(Quest)>) | Общая |
| [Disappointment](<https://rikagro.ru/wiki/Disappointment>) | Общая |
| [Dispatcher Flora](<https://rikagro.ru/wiki/Dispatcher_Flora>) | Ежедневные |
| [Dragon Test (Quest)](<https://rikagro.ru/wiki/Dragon_Test_(Quest)>) | Общая |
| [Dreaming Path (Quest)](<https://rikagro.ru/wiki/Dreaming_Path_(Quest)>) | Общая |
| [Druid Recruitment (Quest)](<https://rikagro.ru/wiki/Druid_Recruitment_(Quest)>) | Общая, Найм |
| [Elementalist Recruitment (Quest)](<https://rikagro.ru/wiki/Elementalist_Recruitment_(Quest)>) | Общая, Найм |
| [Empress Recruitment (Quest)](<https://rikagro.ru/wiki/Empress_Recruitment_(Quest)>) | Общая, Найм |
| [Enchanted Bones (quest)](<https://rikagro.ru/wiki/Enchanted_Bones_(quest)>) | Общая |
| [Encyclopedia](<https://rikagro.ru/wiki/Encyclopedia>) | Общая |
| [Exorcist Recruitment (Quest)](<https://rikagro.ru/wiki/Exorcist_Recruitment_(Quest)>) | Общая, Найм |
| [Exploration Activities (Quest)](<https://rikagro.ru/wiki/Exploration_Activities_(Quest)>) | Общая |
| [Exposing the Conspiracy II (Quest)](<https://rikagro.ru/wiki/Exposing_the_Conspiracy_II_(Quest)>) | Общая, Ежедневные |
| [Farewell](<https://rikagro.ru/wiki/Farewell>) | Общая |
| [Finding Amarieneju (Quest)](<https://rikagro.ru/wiki/Finding_Amarieneju_(Quest)>) | Общая |
| [First Symbol of Rebirth (Quest)](<https://rikagro.ru/wiki/First_Symbol_of_Rebirth_(Quest)>) | Общая |
| [For Acknowledgment (Quest)](<https://rikagro.ru/wiki/For_Acknowledgment_(Quest)>) | Общая, Найм |
| [Forest of Spirits (Quest)](<https://rikagro.ru/wiki/Forest_of_Spirits_(Quest)>) | Общая |
| [Freyja's Necklace (Quest)](<https://rikagro.ru/wiki/Freyja's_Necklace_(Quest)>) | Общая |
| [Frozen Adlivun (Quest)](<https://rikagro.ru/wiki/Frozen_Adlivun_(Quest)>) | Общая |
| [General Kshar (quest)](<https://rikagro.ru/wiki/General_Kshar_(quest)>) | Общая |
| [General Recruitment (Quest)](<https://rikagro.ru/wiki/General_Recruitment_(Quest)>) | Общая, Найм |
| [Ghost Town Asylum (Quest)](<https://rikagro.ru/wiki/Ghost_Town_Asylum_(Quest)>) | Общая |
| [Gou Chen Nam's Pure Heart (Quest)](<https://rikagro.ru/wiki/Gou_Chen_Nam's_Pure_Heart_(Quest)>) | Общая, Ежедневные |
| [Grave of Cubes (Quest)](<https://rikagro.ru/wiki/Grave_of_Cubes_(Quest)>) | Общая |
| [Greetings (quest)](<https://rikagro.ru/wiki/Greetings_(quest)>) | Общая |
| [Groundless Rumor (Quest)](<https://rikagro.ru/wiki/Groundless_Rumor_(Quest)>) | Общая, Найм |
| [Guardian of Moscow (Quest)](<https://rikagro.ru/wiki/Guardian_of_Moscow_(Quest)>) | Общая |
| [Guess Who I Am... (quest)](<https://rikagro.ru/wiki/Guess_Who_I_Am..._(quest)>) | Общая |
| [Hanging Gardens (Quest)](<https://rikagro.ru/wiki/Hanging_Gardens_(Quest)>) | Общая |
| [Hermit of the Blue Mountains (Quest)](<https://rikagro.ru/wiki/Hermit_of_the_Blue_Mountains_(Quest)>) | Общая |
| [Hero's Passage (Quest)](<https://rikagro.ru/wiki/Hero's_Passage_(Quest)>) | Общая |
| [Holy Warrior's Soul (Quest)](<https://rikagro.ru/wiki/Holy_Warrior's_Soul_(Quest)>) | Общая |
| [Hugin (Quest)](<https://rikagro.ru/wiki/Hugin_(Quest)>) | Общая |
| [Human Heritage I (Quest)](<https://rikagro.ru/wiki/Human_Heritage_I_(Quest)>) | Общая |
| [Hwarang Recruitment (Quest)](<https://rikagro.ru/wiki/Hwarang_Recruitment_(Quest)>) | Общая, Найм |
| [Id's Request (Quest)](<https://rikagro.ru/wiki/Id's_Request_(Quest)>) | Общая |
| [Into the Fairytale (Quest)](<https://rikagro.ru/wiki/Into_the_Fairytale_(Quest)>) | Общая |
| [Inventor Recruitment (Quest)](<https://rikagro.ru/wiki/Inventor_Recruitment_(Quest)>) | Общая, Найм |
| [Is There a Tamed Dinosaur (quest)](<https://rikagro.ru/wiki/Is_There_a_Tamed_Dinosaur_(quest)>) | Общая |
| [Janissary Recruitment (Quest)](<https://rikagro.ru/wiki/Janissary_Recruitment_(Quest)>) | Общая, Найм |
| [Jiuzhaigou Ghost Town (Quest)](<https://rikagro.ru/wiki/Jiuzhaigou_Ghost_Town_(Quest)>) | Общая |
| [Kashgar Area Suppression](<https://rikagro.ru/wiki/Kashgar_Area_Suppression>) | Общая |
| [Katherine at Katherine Gorge (Quest)](<https://rikagro.ru/wiki/Katherine_at_Katherine_Gorge_(Quest)>) | Общая |
| [Katherine Gorge (Quest)](<https://rikagro.ru/wiki/Katherine_Gorge_(Quest)>) | Общая |
| [Kriemhild's Forest (Quest)](<https://rikagro.ru/wiki/Kriemhild's_Forest_(Quest)>) | Общая |
| [Labyrinthos (Quest)](<https://rikagro.ru/wiki/Labyrinthos_(Quest)>) | Общая |
| [Lady Knight Recruitment (Quest)](<https://rikagro.ru/wiki/Lady_Knight_Recruitment_(Quest)>) | Общая, Найм |
| [Last Favor (Princess Hwa Man quest)](<https://rikagro.ru/wiki/Last_Favor_(Princess_Hwa_Man_quest)>) | Общая |
| [Last Favor (quest)](<https://rikagro.ru/wiki/Last_Favor_(quest)>) | Общая |
| [Legendary Hero (Quest)](<https://rikagro.ru/wiki/Legendary_Hero_(Quest)>) | Общая, Найм |
| [Legion](<https://rikagro.ru/wiki/Legion>) | Общая |
| [Legion Storage Slot Expansion (Quest)](<https://rikagro.ru/wiki/Legion_Storage_Slot_Expansion_(Quest)>) | Общая, Ежедневные |
| [Legion Storage Slot Expansion Hidden (Quest)](<https://rikagro.ru/wiki/Legion_Storage_Slot_Expansion_Hidden_(Quest)>) | Общая, Ежедневные |
| [Let's Share Drinks Someday! (quest)](<https://rikagro.ru/wiki/Let's_Share_Drinks_Someday%21_(quest)>) | Общая |
| [Lijiang Women's Village (Quest)](<https://rikagro.ru/wiki/Lijiang_Women's_Village_(Quest)>) | Общая |
| [Lost City (Quest)](<https://rikagro.ru/wiki/Lost_City_(Quest)>) | Общая, Найм |
| [Lost Moonlight Orb (Quest)](<https://rikagro.ru/wiki/Lost_Moonlight_Orb_(Quest)>) | Общая |
| [Lost Volcano Valley (Quest)](<https://rikagro.ru/wiki/Lost_Volcano_Valley_(Quest)>) | Общая |
| [Lucky Coin 1 (Quest)](<https://rikagro.ru/wiki/Lucky_Coin_1_(Quest)>) | Общая, Ежедневные |
| [Lucky Coin 2 (Quest)](<https://rikagro.ru/wiki/Lucky_Coin_2_(Quest)>) | Общая, Ежедневные |
| [Lucky Coin 3 (Quest)](<https://rikagro.ru/wiki/Lucky_Coin_3_(Quest)>) | Общая, Ежедневные |
| [Lucky Coin 4 (Quest)](<https://rikagro.ru/wiki/Lucky_Coin_4_(Quest)>) | Общая, Ежедневные |
| [Lucky Coin 5 (Quest)](<https://rikagro.ru/wiki/Lucky_Coin_5_(Quest)>) | Общая, Ежедневные |
| [Lucky Coin 6 (Quest)](<https://rikagro.ru/wiki/Lucky_Coin_6_(Quest)>) | Общая, Ежедневные |
| [Machine Shrine (Quest)](<https://rikagro.ru/wiki/Machine_Shrine_(Quest)>) | Общая |
| [Magician's Tower (Quest)](<https://rikagro.ru/wiki/Magician's_Tower_(Quest)>) | Общая |
| [Mercenary Arthur Specialization (Quest)](<https://rikagro.ru/wiki/Mercenary_Arthur_Specialization_(Quest)>) | Общая |
| [Mimir (Quest)](<https://rikagro.ru/wiki/Mimir_(Quest)>) | Общая |
| [Minstrel Recruitment (Quest)](<https://rikagro.ru/wiki/Minstrel_Recruitment_(Quest)>) | Общая, Найм |
| [Mohenjodaro (Quest)](<https://rikagro.ru/wiki/Mohenjodaro_(Quest)>) | Общая |
| [Momotaro (Quest)](<https://rikagro.ru/wiki/Momotaro_(Quest)>) | Общая |
| [Monk Recruitment (Quest)](<https://rikagro.ru/wiki/Monk_Recruitment_(Quest)>) | Общая, Найм |
| [Mortality (Quest)](<https://rikagro.ru/wiki/Mortality_(Quest)>) | Общая |
| [Mount Huaguo Temple (Quest)](<https://rikagro.ru/wiki/Mount_Huaguo_Temple_(Quest)>) | Общая |
| [Mysterious Magnifying Glass (Quest)](<https://rikagro.ru/wiki/Mysterious_Magnifying_Glass_(Quest)>) | Общая |
| [Mystery (Quest)](<https://rikagro.ru/wiki/Mystery_(Quest)>) | Общая |
| [Navigator's Dream (Quest)](<https://rikagro.ru/wiki/Navigator's_Dream_(Quest)>) | Общая |
| [Necropolis (Quest)](<https://rikagro.ru/wiki/Necropolis_(Quest)>) | Общая |
| [Nest of Insects (Quest)](<https://rikagro.ru/wiki/Nest_of_Insects_(Quest)>) | Общая |
| [Noble Shaman's Soul (Quest)](<https://rikagro.ru/wiki/Noble_Shaman's_Soul_(Quest)>) | Общая |
| [Ocean Abyss (Quest)](<https://rikagro.ru/wiki/Ocean_Abyss_(Quest)>) | Общая |
| [Oncoming Danger (Quest)](<https://rikagro.ru/wiki/Oncoming_Danger_(Quest)>) | Общая |
| [Oracle Recruitment (Quest)](<https://rikagro.ru/wiki/Oracle_Recruitment_(Quest)>) | Общая, Найм |
| [Ordering the Void (Quest)](<https://rikagro.ru/wiki/Ordering_the_Void_(Quest)>) | Общая |
| [Overdrive (Quest)](<https://rikagro.ru/wiki/Overdrive_(Quest)>) | Общая |
| [Patriot Recruitment (Quest)](<https://rikagro.ru/wiki/Patriot_Recruitment_(Quest)>) | Общая, Найм |
| [Pinoccio (quest)](<https://rikagro.ru/wiki/Pinoccio_(quest)>) | Общая |
| [Pirate Recruitment (Quest)](<https://rikagro.ru/wiki/Pirate_Recruitment_(Quest)>) | Общая, Найм |
| [Prankster (Quest)](<https://rikagro.ru/wiki/Prankster_(Quest)>) | Общая, Ежедневные |
| [Princess Fausta (Quest)](<https://rikagro.ru/wiki/Princess_Fausta_(Quest)>) | Общая |
| [Prison Riot (Quest)](<https://rikagro.ru/wiki/Prison_Riot_(Quest)>) | Общая, Ежедневные |
| [Prophet Recruitment (Quest)](<https://rikagro.ru/wiki/Prophet_Recruitment_(Quest)>) | Общая, Найм |
| [Protector of Virgins (quest)](<https://rikagro.ru/wiki/Protector_of_Virgins_(quest)>) | Общая |
| [Pure Waters (Quest)](<https://rikagro.ru/wiki/Pure_Waters_(Quest)>) | Общая |
| [Qualification Test 1 (quest)](<https://rikagro.ru/wiki/Qualification_Test_1_(quest)>) | Общая |
| [Qualification Test 2 (quest)](<https://rikagro.ru/wiki/Qualification_Test_2_(quest)>) | Общая |
| [Qualification Test 3 (quest)](<https://rikagro.ru/wiki/Qualification_Test_3_(quest)>) | Общая |
| [Queen's Orders](<https://rikagro.ru/wiki/Queen's_Orders>) | Общая |
| [Quest](<https://rikagro.ru/wiki/Quest>) | Общая |
| [Quest (craft)](<https://rikagro.ru/wiki/Quest_(craft)>) | Общая |
| [Quest Chain](<https://rikagro.ru/wiki/Quest_Chain>) | Общая |
| [Quick Perfume Recipe (quest)](<https://rikagro.ru/wiki/Quick_Perfume_Recipe_(quest)>) | Общая |
| [Quiz (Quest)](<https://rikagro.ru/wiki/Quiz_(Quest)>) | Общая |
| [Raging Vortex (Quest)](<https://rikagro.ru/wiki/Raging_Vortex_(Quest)>) | Общая |
| [Ready To Awaken 2-2 (quest)](<https://rikagro.ru/wiki/Ready_To_Awaken_2-2_(quest)>) | Общая |
| [Ready to Awaken 3 (quest)](<https://rikagro.ru/wiki/Ready_to_Awaken_3_(quest)>) | Общая |
| [Recruit Arthur (Quest)](<https://rikagro.ru/wiki/Recruit_Arthur_(Quest)>) | Общая, Найм |
| [Recruit Guangmo (Quest)](<https://rikagro.ru/wiki/Recruit_Guangmo_(Quest)>) | Общая, Найм |
| [Recruitment](<https://rikagro.ru/wiki/Recruitment>) | Найм |
| [Red Eyeballs (quest)](<https://rikagro.ru/wiki/Red_Eyeballs_(quest)>) | Общая |
| [Reflect and Reflect Again (Quest)](<https://rikagro.ru/wiki/Reflect_and_Reflect_Again_(Quest)>) | Общая, Ежедневные |
| [Road to Atlantis (Quest)](<https://rikagro.ru/wiki/Road_to_Atlantis_(Quest)>) | Общая |
| [Robbers' Hideout (Quest)](<https://rikagro.ru/wiki/Robbers'_Hideout_(Quest)>) | Общая |
| [Roboto's Love (Quest)](<https://rikagro.ru/wiki/Roboto's_Love_(Quest)>) | Общая |
| [Roro Kidul Recruitment (Quest)](<https://rikagro.ru/wiki/Roro_Kidul_Recruitment_(Quest)>) | Общая, Найм |
| [Ruined Labyrinth (Quest)](<https://rikagro.ru/wiki/Ruined_Labyrinth_(Quest)>) | Общая |
| [Ruric's Broken Axe (quest)](<https://rikagro.ru/wiki/Ruric's_Broken_Axe_(quest)>) | Общая |
| [Ruric's Broken Shield (quest)](<https://rikagro.ru/wiki/Ruric's_Broken_Shield_(quest)>) | Общая |
| [Sanctum of Eternal Sleep (Quest)](<https://rikagro.ru/wiki/Sanctum_of_Eternal_Sleep_(Quest)>) | Общая |
| [Sanctum's Secret (Quest)](<https://rikagro.ru/wiki/Sanctum's_Secret_(Quest)>) | Общая, Ежедневные |
| [Sea of Clouds Tower (Quest)](<https://rikagro.ru/wiki/Sea_of_Clouds_Tower_(Quest)>) | Общая |
| [Sea Palace (Quest)](<https://rikagro.ru/wiki/Sea_Palace_(Quest)>) | Общая |
| [Secrets of the Deep (Quest)](<https://rikagro.ru/wiki/Secrets_of_the_Deep_(Quest)>) | Общая, Ежедневные |
| [Secrets of Time](<https://rikagro.ru/wiki/Secrets_of_Time>) | Общая |
| [Shadow Membership Test (Quest)](<https://rikagro.ru/wiki/Shadow_Membership_Test_(Quest)>) | Общая |
| [Shaolin in Danger (Quest)](<https://rikagro.ru/wiki/Shaolin_in_Danger_(Quest)>) | Общая |
| [Shaolin Legion Quest](<https://rikagro.ru/wiki/Shaolin_Legion_Quest>) | Общая |
| [Shaolin Pride (Quest)](<https://rikagro.ru/wiki/Shaolin_Pride_(Quest)>) | Общая |
| [Shaolin Sect 1 (Quest)](<https://rikagro.ru/wiki/Shaolin_Sect_1_(Quest)>) | Общая, Найм |
| [Shaolin Sect 2 (Quest)](<https://rikagro.ru/wiki/Shaolin_Sect_2_(Quest)>) | Общая, Найм |
| [Shen Hong Recruitment (Quest)](<https://rikagro.ru/wiki/Shen_Hong_Recruitment_(Quest)>) | Общая, Найм |
| [Shogun Castle of Death (Quest)](<https://rikagro.ru/wiki/Shogun_Castle_of_Death_(Quest)>) | Общая |
| [Shogun Secret Garden (Quest)](<https://rikagro.ru/wiki/Shogun_Secret_Garden_(Quest)>) | Общая |
| [Silent Detroit (Quest)](<https://rikagro.ru/wiki/Silent_Detroit_(Quest)>) | Общая |
| [Sorcerer's Plot (Quest)](<https://rikagro.ru/wiki/Sorcerer's_Plot_(Quest)>) | Общая |
| [Sorceress (Quest)](<https://rikagro.ru/wiki/Sorceress_(Quest)>) | Общая, Найм |
| [Spartan Recruitment (Quest)](<https://rikagro.ru/wiki/Spartan_Recruitment_(Quest)>) | Общая, Найм |
| [Spartan's Final Mission (Quest)](<https://rikagro.ru/wiki/Spartan's_Final_Mission_(Quest)>) | Общая |
| [Special Sauce (Quest)](<https://rikagro.ru/wiki/Special_Sauce_(Quest)>) | Общая |
| [Speed (quest)](<https://rikagro.ru/wiki/Speed_(quest)>) | Общая |
| [Stigmatized Shrine (Quest)](<https://rikagro.ru/wiki/Stigmatized_Shrine_(Quest)>) | Общая |
| [Succession (Quest)](<https://rikagro.ru/wiki/Succession_(Quest)>) | Общая |
| [Sunken Machine Shrine (Quest)](<https://rikagro.ru/wiki/Sunken_Machine_Shrine_(Quest)>) | Общая |
| [Tartarus Laboratory (Quest)](<https://rikagro.ru/wiki/Tartarus_Laboratory_(Quest)>) | Общая |
| [Test of Courage (quest)](<https://rikagro.ru/wiki/Test_of_Courage_(quest)>) | Общая |
| [Test of Power (quest)](<https://rikagro.ru/wiki/Test_of_Power_(quest)>) | Общая |
| [Test of Pride (quest)](<https://rikagro.ru/wiki/Test_of_Pride_(quest)>) | Общая |
| [Test of Wisdom (quest)](<https://rikagro.ru/wiki/Test_of_Wisdom_(quest)>) | Общая |
| [That Is Not All (quest)](<https://rikagro.ru/wiki/That_Is_Not_All_(quest)>) | Общая |
| [The Duty of a Knight (quest)](<https://rikagro.ru/wiki/The_Duty_of_a_Knight_(quest)>) | Общая |
| [The Evil Cure (quest)](<https://rikagro.ru/wiki/The_Evil_Cure_(quest)>) | Общая |
| [The Explorers (Quest)](<https://rikagro.ru/wiki/The_Explorers_(Quest)>) | Общая |
| [The Iron Doll (Quest)](<https://rikagro.ru/wiki/The_Iron_Doll_(Quest)>) | Общая |
| [The Key to Atlantis (Quest)](<https://rikagro.ru/wiki/The_Key_to_Atlantis_(Quest)>) | Общая |
| [The Last Keyword (quest)](<https://rikagro.ru/wiki/The_Last_Keyword_(quest)>) | Общая |
| [The Last Ringleader (quest)](<https://rikagro.ru/wiki/The_Last_Ringleader_(quest)>) | Общая |
| [The New Journey (Quest)](<https://rikagro.ru/wiki/The_New_Journey_(Quest)>) | Общая |
| [The Past Hero (quest)](<https://rikagro.ru/wiki/The_Past_Hero_(quest)>) | Общая |
| [The Second Step (quest)](<https://rikagro.ru/wiki/The_Second_Step_(quest)>) | Общая |
| [The Second Symbol (quest)](<https://rikagro.ru/wiki/The_Second_Symbol_(quest)>) | Общая |
| [The Strange Spirits (quest)](<https://rikagro.ru/wiki/The_Strange_Spirits_(quest)>) | Общая |
| [The Third Keyword (quest)](<https://rikagro.ru/wiki/The_Third_Keyword_(quest)>) | Общая |
| [The Third Symbol (quest)](<https://rikagro.ru/wiki/The_Third_Symbol_(quest)>) | Общая |
| [The Two Keywords (quest)](<https://rikagro.ru/wiki/The_Two_Keywords_(quest)>) | Общая |
| [The Virtue of Honor (quest)](<https://rikagro.ru/wiki/The_Virtue_of_Honor_(quest)>) | Общая |
| [The Virtue of Strength](<https://rikagro.ru/wiki/The_Virtue_of_Strength>) | Общая |
| [The Warrior's Path (Quest)](<https://rikagro.ru/wiki/The_Warrior's_Path_(Quest)>) | Общая |
| [The Watcher (quest)](<https://rikagro.ru/wiki/The_Watcher_(quest)>) | Общая |
| [The Yellow River (Quest)](<https://rikagro.ru/wiki/The_Yellow_River_(Quest)>) | Общая |
| [Things to Remember (quest)](<https://rikagro.ru/wiki/Things_to_Remember_(quest)>) | Общая |
| [Time Defense 1 (Quest)](<https://rikagro.ru/wiki/Time_Defense_1_(Quest)>) | Общая, Ежедневные |
| [Title 1 (Quest)](<https://rikagro.ru/wiki/Title_1_(Quest)>) | Общая |
| [Title 2 (Quest)](<https://rikagro.ru/wiki/Title_2_(Quest)>) | Общая |
| [Title 3 (Quest)](<https://rikagro.ru/wiki/Title_3_(Quest)>) | Общая |
| [Title 4 (Quest)](<https://rikagro.ru/wiki/Title_4_(Quest)>) | Общая |
| [To Hwa Man (quest)](<https://rikagro.ru/wiki/To_Hwa_Man_(quest)>) | Общая |
| [Together with a Beautiful Rainbow (quest)](<https://rikagro.ru/wiki/Together_with_a_Beautiful_Rainbow_(quest)>) | Общая |
| [Tormenting (quest)](<https://rikagro.ru/wiki/Tormenting_(quest)>) | Общая |
| [Trip to Angkor Wat (Quest)](<https://rikagro.ru/wiki/Trip_to_Angkor_Wat_(Quest)>) | Общая |
| [Trip to Cathedral (Quest)](<https://rikagro.ru/wiki/Trip_to_Cathedral_(Quest)>) | Общая |
| [Trip to Colosseum (Quest)](<https://rikagro.ru/wiki/Trip_to_Colosseum_(Quest)>) | Общая |
| [Trip to Stonehenge (Quest)](<https://rikagro.ru/wiki/Trip_to_Stonehenge_(Quest)>) | Общая |
| [Trip to Taj Mahal (Quest)](<https://rikagro.ru/wiki/Trip_to_Taj_Mahal_(Quest)>) | Общая |
| [Trojan War](<https://rikagro.ru/wiki/Trojan_War>) | Общая |
| [Troublemaker on the Street (quest)](<https://rikagro.ru/wiki/Troublemaker_on_the_Street_(quest)>) | Общая |
| [Tundra Outskirts (Quest)](<https://rikagro.ru/wiki/Tundra_Outskirts_(Quest)>) | Общая |
| [Unfinished Love (quest)](<https://rikagro.ru/wiki/Unfinished_Love_(quest)>) | Общая |
| [Valhalla's Bow (Quest)](<https://rikagro.ru/wiki/Valhalla's_Bow_(Quest)>) | Общая |
| [Valkyrie Mercenary Recruitment (Quest)](<https://rikagro.ru/wiki/Valkyrie_Mercenary_Recruitment_(Quest)>) | Общая, Найм |
| [Valley of the Kings (Quest)](<https://rikagro.ru/wiki/Valley_of_the_Kings_(Quest)>) | Общая |
| [Van Gogh Gallery (Quest)](<https://rikagro.ru/wiki/Van_Gogh_Gallery_(Quest)>) | Общая |
| [Van Gogh's Hometown](<https://rikagro.ru/wiki/Van_Gogh's_Hometown>) | Общая |
| [Warrior's Path (Quest)](<https://rikagro.ru/wiki/Warrior's_Path_(Quest)>) | Общая |
| [Weird Looking Survivors (quest)](<https://rikagro.ru/wiki/Weird_Looking_Survivors_(quest)>) | Общая |
| [White Haired Witch Recruitment (Quest)](<https://rikagro.ru/wiki/White_Haired_Witch_Recruitment_(Quest)>) | Общая |
| [Witch Recruitment (Quest)](<https://rikagro.ru/wiki/Witch_Recruitment_(Quest)>) | Общая, Найм |
| [Witch's Lab (Quest)](<https://rikagro.ru/wiki/Witch's_Lab_(Quest)>) | Общая |
| [Wulin (Quest)](<https://rikagro.ru/wiki/Wulin_(Quest)>) | Общая |
| [Wuyi Palace's Wen Xie (quest)](<https://rikagro.ru/wiki/Wuyi_Palace's_Wen_Xie_(quest)>) | Общая |
| [Yggdrasil (Quest)](<https://rikagro.ru/wiki/Yggdrasil_(Quest)>) | Общая |
| [Young Man's Pure Heart (Quest)](<https://rikagro.ru/wiki/Young_Man's_Pure_Heart_(Quest)>) | Общая |
