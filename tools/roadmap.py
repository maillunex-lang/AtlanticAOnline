#!/usr/bin/env python3
"""Дорожная карта как единый источник правды: docs/plan/tasks.json.
ROADMAP.md генерируется командой `render`, руками его не правят.

Команды:
  next                    показать следующую задачу (первая готовая по порядку) и всё, что нужно для работы
  show WP-xx              карточка задачи
  start WP-xx             взять задачу в работу
  done WP-xx --note "..." [--commit HASH] [--tests N]   закрыть задачу с отчётом
  partial WP-xx --note "..."   выполнено частично (остаток записать в заметку)
  block WP-xx --note "..."     заблокирована (причина)
  log WP-xx --note "..."       добавить запись в журнал задачи, статус не менять
  note --text "..."        общая запись в журнал проекта (решение, находка, риск)
  tests N                  записать число проходящих тестов
  check                    проверить целостность (зависимости, циклы, ссылки на документы)
  render                   пересобрать ROADMAP.md
"""
import json, sys, os, re, argparse, datetime

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TASKS = os.path.join(ROOT, "docs", "plan", "tasks.json")
OUT = os.path.join(ROOT, "ROADMAP.md")
ST = {"todo": "[ ]", "in_progress": "[~]", "partial": "[◐]", "blocked": "[!]", "done": "[x]"}
WHO = os.environ.get("ROADMAP_AUTHOR", "ИИ-исполнитель")


def load():
    return json.load(open(TASKS, encoding="utf-8"))


def save(d):
    with open(TASKS, "w", encoding="utf-8") as f:
        json.dump(d, f, ensure_ascii=False, indent=1)
        f.write("\n")


def by_id(d):
    return {t["id"]: t for t in d["tasks"]}


def today():
    return datetime.date.today().isoformat()


def ready(d):
    ids = by_id(d)
    out = []
    for t in d["tasks"]:
        if t["status"] in ("todo", "partial", "in_progress") and all(ids[x]["status"] == "done" for x in t["deps"] if x in ids):
            out.append(t)
    out.sort(key=lambda t: (t["status"] != "in_progress", t.get("order", 999)))
    return out


def card(d, t):
    ids = by_id(d)
    ph = d["phases"][t["phase"]]
    L = [f"{t['id']}  {t['title']}  [{t['status']}]  размер {t['size']}",
         f"Фаза: {ph['title']}  (веха {t['milestone']})",
         "Зависит от: " + (", ".join(f"{x} ({ids[x]['status']})" for x in t["deps"]) or "—") + (f"  ({t['deps_note']})" if t.get("deps_note") else ""),
         "Что сделать: " + t["what"],
         "Приёмка: " + t["acceptance"],
         "Читать до начала: " + "; ".join(["docs/plan/DESIGN_GUARD.md"] + t["sources"]),
         "Шлюз GitHub: " + ph["gate"] + " (docs/plan/GITHUB_RESEARCH.md)"]
    if t.get("notes"):
        L.append("Заметки: " + t["notes"])
    for e in t.get("log", []):
        L.append(f"  - {e['date']} {e['who']}" + (f" {e['commit']}" if e.get("commit") else "") + f": {e['text']}")
    return "\n".join(L)


def render(d):
    ids = by_id(d)
    tasks = d["tasks"]
    n = {k: sum(1 for t in tasks if t["status"] == k) for k in ST}
    total = len(tasks)
    rd = ready(d)
    cur = [t for t in tasks if t["status"] == "in_progress"]
    L = []
    A = L.append
    A("# ROADMAP — Atlantic Online")
    A("")
    A("> **Файл сгенерирован** `python3 tools/roadmap.py render` из `docs/plan/tasks.json`. Руками не править: меняйте задачи командами `tools/roadmap.py`.")
    A("")
    A("## 0. Как работать (одинаково для любого ИИ-исполнителя; вы и директор, и исполнитель)")
    A("")
    A("**Роль директора (выбор и контроль):**")
    A("1. Прочитайте `docs/plan/AI_HANDOFF.md` (состояние проекта, команды, грабли) и `docs/plan/DESIGN_GUARD.md` (что нельзя ломать).")
    A("2. `python3 tools/roadmap.py next` покажет следующую задачу (первая по порядку, у которой выполнены зависимости), документы для чтения, приёмку и шлюз GitHub.")
    A("3. Если задачу уже кто-то взял (`[~]`), не берите её: возьмите следующую из списка «Готовы к работе» ниже.")
    A("4. Если фаза новая: выполните **шлюз** (поиск на GitHub по `docs/plan/GITHUB_RESEARCH.md`), запишите результат в `docs/stages/<фаза>_GITHUB_CANDIDATES.md`.")
    A("")
    A("**Роль исполнителя (работа):**")
    A("5. `python3 tools/roadmap.py start WP-xx` (отметка «в работе»).")
    A("6. Прочитайте источники из карточки (`show WP-xx`): правила оригинала в `docs/plan/wiki/`, дизайн в соответствующих GDD и документах `docs/plan/`.")
    A("7. Реализуйте: логика в `src/shared` (чистая, детерминированная), числа и контент в `data/*.json`, тесты gdUnit4, для интерфейса скриншоты (16:9 и 2.2:1). Команды сборки и тестов в `docs/plan/AI_HANDOFF.md`.")
    A("8. **Приёмка (директор проверяет себя):** все тесты зелёные, `GameData.validate()` проходит, критерий приёмки из карточки выполнен, нет нарушений DESIGN_GUARD.md, документ раздела обновлён, `docs/DECISIONS.md` дополнен, если приняты решения.")
    A("9. Закройте: `python3 tools/roadmap.py done WP-xx --note \"что сделано, что осталось, какие решения\" --commit <хеш> --tests <число>`; затем `python3 tools/roadmap.py render`. Частично выполнено: `partial` (остаток опишите, он остаётся в очереди). Мешает внешняя причина: `block`.")
    A("10. Коммит и пуш прямо в `main` (код, данные, документы, `tasks.json`, `ROADMAP.md` вместе). Затем снова шаг 2.")
    A("")
    A("**Правила журнала:** любое решение, находку, ошибку или риск записывайте `tools/roadmap.py note --text \"...\"` или `log WP-xx --note \"...\"`; честно отмечайте непроверенное («на устройстве не запускалось»). Правила работают без истории чата: всё нужное лежит в репозитории.")
    A("")
    A("**Статусы:** `[ ]` не начата, `[~]` в работе, `[◐]` частично (остаток в заметке), `[!]` заблокирована, `[x]` сделано.")
    A("")
    A("## 1. Состояние")
    A(f"- Задач: {total}. Сделано {n['done']}, частично {n['partial']}, в работе {n['in_progress']}, заблокировано {n['blocked']}, не начато {n['todo']}.")
    A(f"- Тестов проходит: **{d['meta']['tests']}** (на {d['meta']['tests_date']}). Демо Android собирается; на реальном телефоне не проверено.")
    A("- Логика (`src/shared`) готова как ядро и не подключена к сети: клиент и сервер вместе не запускались (главный накопленный риск, закрывает M3).")
    A("- Видение зафиксировано: пиксель-арт 16x16 x4, вид сверху, бой формаций 3x3, горизонтальная ориентация (`docs/GDD.md` п. 2.1). Графика Kenney CC0 временная.")
    A("")
    A("## 2. Сейчас делать")
    if cur:
        A("**В работе:** " + ", ".join(f"{t['id']} {t['title']}" for t in cur))
    if rd:
        t = rd[0]
        A(f"**Следующая задача: {t['id']} — {t['title']}** (размер {t['size']}, фаза «{d['phases'][t['phase']]['title']}»).")
        A(f"- Что сделать: {t['what']}")
        A(f"- Приёмка: {t['acceptance']}")
        A("- Читать: " + "; ".join(t["sources"]))
        A("")
        A("Готовы к работе (зависимости выполнены), по порядку:")
        for t in rd[:12]:
            A(f"- {t['id']} {t['title']} ({t['size']})")
    A("")
    A("## 3. Вехи")
    A("| Веха | Содержание | Задач | Готово |")
    A("|------|-----------|--------|--------|")
    for m in d["milestones"]:
        ts = [t for t in tasks if t["milestone"] == m["id"]]
        dn = sum(1 for t in ts if t["status"] == "done")
        A(f"| {m['id']} | {m['title']} | {len(ts)} | {dn}/{len(ts)} |")
    A("")
    A("## 4. Все задачи по порядку")
    A("Таблицы сгруппированы по фазам. **Порядок выполнения задаёт поле `order` в tasks.json** (его учитывает `next`); зависимости обязательны. Сеть (фаза 7) можно вести параллельно фазам 2-4.")
    A("Рекомендуемая последовательность: " + " → ".join(t["id"] for t in sorted((t for t in tasks if t.get("order", 999) >= 0), key=lambda t: t.get("order", 999))[:20]) + " → ...")
    for pid, ph in d["phases"].items():
        A("")
        A(f"### {ph['title']}")
        A(f"Шлюз GitHub: {ph['gate']}. Источники: " + "; ".join(ph["sources"]))
        A("")
        A("| | WP | Задача | Разм. | Зависит | Приёмка |")
        A("|--|----|--------|-------|---------|---------|")
        for t in tasks:
            if t["phase"] != pid:
                continue
            dep = ", ".join(t["deps"]) or "—"
            if t.get("deps_note"):
                dep += f" ({t['deps_note']})"
            A(f"| {ST[t['status']]} | {t['id']} | {t['title']} | {t['size']} | {dep} | {t['acceptance']} |")
    A("")
    A("## 5. Журнал работ (последние 25 записей)")
    ent = []
    for t in tasks:
        for e in t.get("log", []):
            ent.append((e["date"], t["id"], e))
    for e in d.get("journal", []):
        ent.append((e["date"], "—", e))
    ent.sort(key=lambda x: x[0], reverse=True)
    if not ent:
        A("Записей пока нет.")
    for date, tid, e in ent[:25]:
        A(f"- {date} **{tid}** {e['who']}" + (f" (`{e['commit']}`)" if e.get("commit") else "") + f": {e['text']}")
    A("")
    A("## 6. Известные пробелы и риски")
    for r in d["risks"]:
        A(f"- {r}")
    A("")
    A("## 7. Где что лежит")
    A("- Протокол и состояние проекта: `docs/plan/AI_HANDOFF.md`. Охранные правила: `docs/plan/DESIGN_GUARD.md`. Описание всех систем: `docs/plan/GAME_SPEC.md`.")
    A("- Правила оригинала и числа: `docs/plan/wiki/` и `docs/plan/reference/wiki_numbers.json`. Мир: `docs/plan/WORLD_DESIGN.md`. Квесты: `docs/plan/QUEST_DESIGN.md`. Как добавлять контент: `docs/plan/CONTENT_PIPELINE.md`.")
    A("- Принятое и реализованное: `docs/GDD*.md`, `docs/DECISIONS.md`. Поиск на GitHub: `docs/plan/GITHUB_RESEARCH.md`, результаты `docs/stages/`. Указатель: `docs/README.md`.")
    open(OUT, "w", encoding="utf-8").write("\n".join(L) + "\n")


def check(d):
    ids = by_id(d)
    err = []
    if len(ids) != len(d["tasks"]):
        err.append("повторяющиеся id")
    for t in d["tasks"]:
        if t["status"] not in ST:
            err.append(f"{t['id']}: статус {t['status']}")
        if t["phase"] not in d["phases"]:
            err.append(f"{t['id']}: нет фазы")
        for x in t["deps"]:
            if x not in ids:
                err.append(f"{t['id']}: нет зависимости {x}")
        for s in t["sources"]:
            p = s.split("#")[0].split(" ")[0]
            if not os.path.exists(os.path.join(ROOT, p)):
                err.append(f"{t['id']}: нет файла {p}")
        if t["status"] == "done" and any(ids[x]["status"] != "done" for x in t["deps"] if x in ids):
            err.append(f"{t['id']}: сделана раньше зависимостей")
    seen, stack = set(), set()

    def dfs(x):
        if x in stack:
            err.append(f"цикл через {x}")
            return
        if x in seen:
            return
        stack.add(x)
        for y in ids[x]["deps"]:
            if y in ids:
                dfs(y)
        stack.discard(x)
        seen.add(x)
    for x in ids:
        dfs(x)
    return err


def main():
    ap = argparse.ArgumentParser(add_help=False)
    ap.add_argument("cmd")
    ap.add_argument("arg", nargs="?")
    ap.add_argument("--note", default="")
    ap.add_argument("--text", default="")
    ap.add_argument("--commit", default="")
    ap.add_argument("--tests", default="")
    a = ap.parse_args()
    d = load()
    ids = by_id(d)
    c = a.cmd
    if c in ("-h", "--help", "help"):
        print(__doc__)
        return
    if c == "next":
        rd = ready(d)
        if not rd:
            print("Готовых задач нет: проверьте блокировки (`check`).")
            return
        print(card(d, rd[0]))
        print("\nДругие готовые: " + ", ".join(t["id"] for t in rd[1:8]))
        return
    if c == "show":
        print(card(d, ids[a.arg]))
        return
    if c in ("start", "done", "partial", "block", "log"):
        t = ids[a.arg]
        entry = lambda txt: {"date": today(), "who": WHO, "text": txt, **({"commit": a.commit} if a.commit else {})}
        if c == "start":
            t["status"] = "in_progress"
            t.setdefault("log", []).append(entry("взята в работу"))
        elif c == "done":
            if not a.note:
                sys.exit("нужен --note с отчётом")
            miss = [x for x in t["deps"] if ids[x]["status"] != "done"]
            if miss:
                sys.exit("зависимости не выполнены: " + ", ".join(miss))
            t["status"] = "done"
            t["done_date"] = today()
            t.setdefault("log", []).append(entry("СДЕЛАНО: " + a.note))
        elif c == "partial":
            t["status"] = "partial"
            t.setdefault("log", []).append(entry("ЧАСТИЧНО: " + a.note))
        elif c == "block":
            t["status"] = "blocked"
            t.setdefault("log", []).append(entry("ЗАБЛОКИРОВАНО: " + a.note))
        else:
            t.setdefault("log", []).append(entry(a.note))
        if a.tests:
            d["meta"]["tests"] = int(a.tests)
            d["meta"]["tests_date"] = today()
    elif c == "note":
        d.setdefault("journal", []).append({"date": today(), "who": WHO, "text": a.text or a.note, **({"commit": a.commit} if a.commit else {})})
    elif c == "tests":
        d["meta"]["tests"] = int(a.arg)
        d["meta"]["tests_date"] = today()
    elif c == "check":
        e = check(d)
        print("OK" if not e else "\n".join(e))
        sys.exit(1 if e else 0)
    elif c == "render":
        pass
    else:
        sys.exit("неизвестная команда, см. help")
    save(d)
    render(d)
    print("готово: tasks.json и ROADMAP.md обновлены")


if __name__ == "__main__":
    main()
