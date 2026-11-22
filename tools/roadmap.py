#!/usr/bin/env python3
"""Дорожная карта как единый источник правды: docs/plan/tasks.json.
ROADMAP.md генерируется командой `render`, руками его не правят.

Команды:
  next                    показать следующую задачу (первая готовая по порядку) и всё, что нужно для работы
  show ID                 полная карточка и журнал
  context ID              краткий контекст с последней точкой передачи
  checkpoint ID --note "..." --next "..."  сохранить точку продолжения
  report ID               отчёт о завершении
  start WP-xx [--take]    взять задачу в работу (зависимости должны быть выполнены; чужую задачу брать только с --take)
  done WP-xx --note "..." (--commit HASH | --ci URL | --manual "что проверено") [--tests N]   закрыть задачу с подтверждением
                          (задача должна быть в работе; у ручных задач только --manual)
  partial WP-xx --note "..."   выполнено частично (остаток записать в заметку)
  block WP-xx --note "..."     заблокирована (причина)
  log WP-xx --note "..."       добавить запись в журнал задачи, статус не менять
  note --text "..."        общая запись в журнал проекта (решение, находка, риск)
  ask --text "..." [--wp WP-xx]   вопрос владельцу (решение, которое исполнитель принимать не вправе); работа продолжается над другими задачами
  decide ID --text "..."   записать ответ владельца на вопрос
  tests N                  записать число проходящих тестов
  check                    проверить целостность (зависимости, циклы, ссылки на документы)
  render                   пересобрать ROADMAP.md
"""
import json, sys, os, re, argparse, datetime
from pathlib import Path
from urllib.parse import unquote

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TASKS = os.path.join(ROOT, "docs", "plan", "tasks.json")
OUT = os.path.join(ROOT, "ROADMAP.md")
ST = {"todo": "[ ]", "in_progress": "[~]", "partial": "[◐]", "blocked": "[!]", "done": "[x]"}
WHO = os.environ.get("ROADMAP_AUTHOR", "ИИ-исполнитель")


def load():
    with open(TASKS, encoding="utf-8") as file:
        data = json.load(file)
    data["tasks"].extend(data.pop("work_items", []))
    return data


def is_package(t):
    return t["id"].startswith("WP-") and not t.get("parent")


def save(d):
    output = {**d, "tasks": [t for t in d["tasks"] if is_package(t)],
              "work_items": [t for t in d["tasks"] if not is_package(t)]}
    with open(TASKS, "w", encoding="utf-8") as f:
        json.dump(output, f, ensure_ascii=False, indent=1)
        f.write("\n")


def by_id(d):
    return {t["id"]: t for t in d["tasks"]}


def today():
    return datetime.date.today().isoformat()


def children(d, tid):
    return [t for t in d["tasks"] if t.get("parent") == tid]


def approval(d, t):
    parent = by_id(d).get(t.get("parent"), {})
    return t.get("requires_approval") or parent.get("requires_approval")


def ready(d, me=None):
    ids = by_id(d)
    out = [
        t for t in d["tasks"]
        if t["status"] in ("todo", "partial", "in_progress")
        and all(ids.get(x, {}).get("status") == "done" for x in t["deps"])
        and all(child["status"] == "done" for child in children(d, t["id"]))
        and not approval(d, t)
        and not t.get("coordinated_by")
        and (t["status"] != "in_progress" or t.get("owner") == me)
    ]
    return sorted(out, key=lambda t: (t["status"] != "in_progress", t["order"], t["id"]))


def verification(t):
    return t.get("verification", [
        "Проверить критерий карточки и запустить подходящий набор gdUnit4 из tests/.",
        "Команды Godot и условия ручной проверки: docs/plan/AI_HANDOFF.md#как-работать.",
    ])


def context(d, t):
    ids = by_id(d)
    lines = [
        f"{t['id']} · {t['title']} [{t['status']}]",
        f"Приоритет (раньше = меньше): {t['order']}",
        "Зависимости: " + (", ".join(f"{x} [{ids[x]['status']}]" for x in t["deps"]) or "—"),
        "Задача: " + t["what"],
        "Готово, если: " + t["acceptance"],
        "Открыть: " + ", ".join(t["sources"]),
        "Проверки: " + " / ".join(verification(t)),
    ]
    if t.get("test_groups") or ids.get(t.get("parent"), {}).get("test_groups"):
        lines.append(f"Выбор тестов: python3 tools/test_runner.py fast --task {t['id']} (также targeted и full)")
    if t.get("parent"):
        lines.append("Родитель: " + t["parent"])
    if t.get("coordinated_by"):
        lines.append("Вести через: " + t["coordinated_by"])
    if approval(d, t):
        lines.append("Разрешение: " + approval(d, t))
    pending = [x["id"] for x in children(d, t["id"]) if x["status"] != "done"]
    if pending:
        lines.append("Оставшиеся этапы: " + ", ".join(pending))
    if t.get("owner"):
        lines.append("Исполнитель: " + t["owner"])
    history = t.get("log", [])
    checkpoint = next((e for e in reversed(history) if "next" in e), None)
    if checkpoint:
        lines.extend(["Передача: " + checkpoint["text"], "Следующий шаг: " + checkpoint["next"]])
    elif history:
        lines.append("Последняя запись: " + history[-1]["text"])
    return "\n".join(lines)


def report(t):
    entry = next((e for e in reversed(t.get("log", []))
                  if e.get("text", "").startswith("СДЕЛАНО:") and any(e.get(k) for k in ("commit", "ci", "manual"))), None)
    if entry is None:
        entry = next((e for e in reversed(t.get("log", []))
                      if any(e.get(k) for k in ("commit", "ci", "manual"))), None)
    if t["status"] != "done" or entry is None:
        raise ValueError("Нет подтверждённого завершения.")
    lines = [f"## {t['id']} — {t['title']}", "", f"{entry['date']} · {entry['who']}", entry["text"]]
    lines.extend(f"- {k}: {entry[k]}" for k in ("commit", "ci", "manual", "tests") if entry.get(k))
    return "\n".join(lines)


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


def render(d, *, write=True):
    ids = by_id(d)
    tasks = d["tasks"]
    packages = [t for t in tasks if is_package(t)]
    n = {k: sum(t["status"] == k for t in packages) for k in ST}
    total = len(packages)
    completion = n["done"] * 100 // total if total else 0
    rd = ready(d, None)
    cur = [t for t in tasks if t["status"] == "in_progress"]
    L = []
    A = L.append
    A("# ROADMAP — Atlantic Online")
    A("")
    A("> **Файл сгенерирован** `python3 tools/roadmap.py render` из `docs/plan/tasks.json`. Руками не править: меняйте задачи командами `tools/roadmap.py`.")
    A("")
    A("## 0. Начало работы")
    A("")
    A("Прочитайте [AGENTS.md](AGENTS.md). Команда `next` выбирает ID. Команда `context ID` показывает источники, критерии и точку продолжения.")
    A("")
    A("## 1. Состояние")
    A(f"- Готово **{n['done']}/{total} ({completion}%)**. Частично {n['partial']}, в работе {n['in_progress']}, заблокировано {n['blocked']}, не начато {n['todo']}.")
    A(f"- Тестов проходит: **{d['meta']['tests']}** (на {d['meta']['tests_date']}).")
    if d["meta"].get("verified_commit") and d["meta"].get("verified_ci"):
        A(f"- Проверенная база: `{d['meta']['verified_commit']}`. [GitHub Actions]({d['meta']['verified_ci']}).")
    if ids.get("WP-03", {}).get("status") == "done":
        A("- Проверка APK на физическом Android закрыта (WP-03). Детали и оставшиеся замеры указаны в журнале.")
    else:
        A("- Проверка APK на физическом Android отслеживается в WP-03.")
    A("- Демо использует общее ядро `src/shared`. SQLite и тестовый вход по ENet готовы. Полный сетевой сценарий движения, боя и награды относится к M3.")
    A("- Видение зафиксировано: пиксель-арт 16x16 x4, вид сверху, бой формаций 3x3, горизонтальная ориентация (`docs/GDD.md` п. 2.1). Графика Kenney CC0 временная.")
    A("")
    A("## 2. Сейчас делать")
    ready_ids = {t["id"] for t in rd}
    groups = {
        "Completed": [t for t in tasks if t["status"] == "done"],
        "In Progress": cur,
        "Ready": rd,
        "Blocked": [t for t in tasks if t["status"] != "done" and (t["status"] == "blocked" or approval(d, t))],
        "Backlog": [t for t in tasks if t["status"] in ("todo", "partial")
                    and t["id"] not in ready_ids and not approval(d, t)],
    }
    for name, group in groups.items():
        A(f"### {name}")
        A("")
        A(", ".join(t["id"] for t in group) or "—")
        A("")
        if name in ("Ready", "In Progress", "Blocked"):
            for t in group:
                reason = approval(d, t) or (t.get("log") or [{}])[-1].get("text", "") if name == "Blocked" else ""
                owner = t.get("owner")
                suffix = reason or (f"исполнитель {owner}" if owner else "")
                A(f"- **{t['id']}** {t['title']}" + (f" · {suffix}" if suffix else ""))
            if group:
                A("")
    op = [q for q in d.get("pending_decisions", []) if q["status"] == "open"]
    A("")
    A("**Ждут решения владельца** (исполнитель продолжает другие задачи):")
    if not op:
        A("- Открытых вопросов нет.")
    for q in op:
        A(f"- #{q['id']} ({q['date']}" + (f", {q['wp']}" if q.get("wp") else "") + f"): {q['text']}")
    A("")
    A("## 3. Вехи")
    A("| Веха | Содержание | Задач | Готово |")
    A("|------|-----------|--------|--------|")
    for m in d["milestones"]:
        ts = [t for t in packages if t["milestone"] == m["id"]]
        dn = sum(1 for t in ts if t["status"] == "done")
        A(f"| {m['id']} | {m['title']} | {len(ts)} | {dn}/{len(ts)} |")
    A("")
    A("## 4. Все задачи по порядку")
    A("Таблицы сгруппированы по фазам. **Порядок выполнения задаёт поле `order` в tasks.json** (его учитывает `next`); зависимости обязательны. Сеть (фаза 7) можно вести параллельно фазам 2-4.")
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
    A("## 5. Отчёт о завершении")
    finished = [t for t in tasks if t["status"] == "done"]
    if finished:
        A("")
        latest = ids.get(d["meta"].get("last_completed"))
        if latest is None:
            latest = max(finished, key=lambda t: t.get("done_date", ""))
        A(report(latest).replace("## ", "### ", 1))
    A("")
    A("## 6. Журнал работ (последние 25 записей)")
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
    A("## 7. Известные пробелы и риски")
    for r in d["risks"]:
        A(f"- {r}")
    A("")
    A("## 8. Где что лежит")
    A("- Вход для Claude Code: [CLAUDE.md](CLAUDE.md). Протокол и состояние проекта: `docs/plan/AI_HANDOFF.md`. Охранные правила: `docs/plan/DESIGN_GUARD.md`. Описание всех систем: `docs/plan/GAME_SPEC.md`.")
    A("- Правила оригинала и числа: `docs/plan/wiki/` и `docs/plan/reference/wiki_numbers.json`. Мир: `docs/plan/WORLD_DESIGN.md`. Квесты: `docs/plan/QUEST_DESIGN.md`. Как добавлять контент: `docs/plan/CONTENT_PIPELINE.md`.")
    A("- Задания для Kimi (WP-101): [дизайн героев](docs/plan/art/KIMI_HERO_DESIGN.md) и [анимация героев](docs/plan/art/KIMI_HERO_ANIMATION.md).")
    A("- Принятое и реализованное: `docs/GDD*.md`, `docs/DECISIONS.md`. Поиск на GitHub: `docs/plan/GITHUB_RESEARCH.md`, результаты `docs/stages/`. Указатель: `docs/README.md`.")
    text = "\n".join(L) + "\n"
    if write:
        Path(OUT).write_text(text, encoding="utf-8")
    return text


def check_links():
    paths = [Path(ROOT, name) for name in (
        "AGENTS.md", "CLAUDE.md", "ROADMAP.md", "docs/plan/BUILD_ORDER.md", "docs/plan/AI_HANDOFF.md",
    )] + sorted(Path(ROOT, "docs/workflow").glob("*.md"))
    pattern = re.compile(r"!?\[[^\]\n]+\]\(([^\s)]+)\)")
    errors = []
    for path in paths:
        if not path.is_file():
            errors.append(f"Нет документа {path.relative_to(ROOT)}")
            continue
        content = re.sub(r"```.*?```", "", path.read_text(encoding="utf-8"), flags=re.S)
        destinations = pattern.findall(content)
        if path.name == "CLAUDE.md":
            destinations += re.findall(r"^@([^\s]+)$", content, re.M)
        for destination in destinations:
            if re.match(r"^[a-z][a-z+.-]*:", destination, re.I):
                continue
            file, _, fragment = unquote(destination).partition("#")
            target = (path.parent / file).resolve() if file else path
            if not target.is_relative_to(ROOT) or not target.exists():
                errors.append(f"{path.relative_to(ROOT)}: нет цели {destination}")
            elif fragment and target.suffix == ".md":
                headings = re.findall(r"^#{1,6}\s+(.+?)\s*$", target.read_text(encoding="utf-8"), re.M)
                slugs = {re.sub(r"[^\w -]", "", h.lower()).replace(" ", "-") for h in headings}
                if fragment not in slugs:
                    errors.append(f"{path.relative_to(ROOT)}: нет раздела {destination}")
    return errors


def check(d):
    ids = by_id(d)
    err = []
    if d["meta"].get("last_completed") and ids.get(d["meta"]["last_completed"], {}).get("status") != "done":
        err.append("last_completed не указывает на закрытую задачу")
    if len(ids) != len(d["tasks"]):
        err.append("повторяющиеся id")
    milestones = {m["id"] for m in d["milestones"]}
    for t in d["tasks"]:
        tid = t["id"]
        if t["milestone"] not in milestones:
            err.append(f"{tid}: нет вехи")
        if not isinstance(t.get("order"), (int, float)):
            err.append(f"{tid}: отсутствует числовой приоритет")
        if not t.get("what") or not t.get("acceptance") or not t.get("sources"):
            err.append(f"{tid}: неполная карточка")
        if len(set(t["deps"])) != len(t["deps"]):
            err.append(f"{tid}: дубли зависимостей")
        parent = t.get("parent")
        if parent and (parent not in ids or ids[parent].get("parent") or not tid.startswith(parent + ".")):
            err.append(f"{tid}: неверный родитель {parent}")
        if t.get("coordinated_by") and (t["coordinated_by"] not in ids or t["coordinated_by"] == tid):
            err.append(f"{tid}: неверный координирующий пакет")
        if t["status"] == "done" and any(x["status"] != "done" for x in children(d, tid)):
            err.append(f"{tid}: незавершённые дочерние этапы")
        if t["status"] not in ST:
            err.append(f"{t['id']}: статус {t['status']}")
        if t["phase"] not in d["phases"]:
            err.append(f"{t['id']}: нет фазы")
        for x in t["deps"]:
            if x not in ids:
                err.append(f"{t['id']}: нет зависимости {x}")
        for s in t["sources"]:
            p = s.split("#", 1)[0]
            if not os.path.exists(os.path.join(ROOT, p)):
                err.append(f"{t['id']}: нет файла {p}")
        if t["status"] == "done" and any(ids[x]["status"] != "done" for x in t["deps"] if x in ids):
            err.append(f"{t['id']}: сделана раньше зависимостей")
        if t["status"] == "done" and not any(e.get("commit") or e.get("ci") or e.get("manual") for e in t.get("log", [])):
            err.append(f"{t['id']}: сделана без подтверждения (коммит, CI или ручная проверка)")
        if t["status"] == "in_progress" and not t.get("owner"):
            err.append(f"{t['id']}: в работе без владельца")
    seen, stack = set(), set()

    def dfs(x):
        if x in stack:
            err.append(f"цикл через {x}")
            return
        if x in seen:
            return
        stack.add(x)
        for y in ids[x]["deps"] + [child["id"] for child in children(d, x)]:
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
    ap.add_argument("--next", default="")
    ap.add_argument("--text", default="")
    ap.add_argument("--commit", default="")
    ap.add_argument("--tests", default="")
    ap.add_argument("--ci", default="")
    ap.add_argument("--manual", default="")
    ap.add_argument("--take", action="store_true")
    ap.add_argument("--wp", default="")
    a = ap.parse_args()
    d = load()
    ids = by_id(d)
    c = a.cmd
    if c in ("-h", "--help", "help"):
        print(__doc__)
        return
    if c == "next":
        rd = ready(d, WHO)
        if not rd:
            print("Готовых задач нет: проверьте блокировки (`check`).")
            return
        print(context(d, rd[0]))
        mine = rd[0]["status"] == "in_progress" and rd[0].get("owner") == WHO
        print("\n" + ("Это ваша задача в работе: продолжайте её." if mine else "Свободная задача: возьмите командой start."))
        print("Другие готовые: " + ", ".join(t["id"] for t in rd[1:8]))
        busy = [t for t in d["tasks"] if t["status"] == "in_progress" and t.get("owner") != WHO]
        if busy:
            print("Заняты другими: " + ", ".join(f"{t['id']} ({t['owner']})" for t in busy))
        return
    if c in ("show", "context", "report"):
        if a.arg not in ids:
            sys.exit("нет такой задачи")
        try:
            print({"show": lambda: card(d, ids[a.arg]), "context": lambda: context(d, ids[a.arg]),
                   "report": lambda: report(ids[a.arg])}[c]())
        except ValueError as error:
            sys.exit(str(error))
        return
    if c in ("start", "done", "partial", "block", "log", "checkpoint"):
        if a.arg not in ids:
            sys.exit("нет такой задачи")
        t = ids[a.arg]
        ev = {}
        for k in ("commit", "ci", "manual"):
            if getattr(a, k):
                ev[k] = getattr(a, k)
        entry = lambda txt: {"date": today(), "who": WHO, "text": txt, **ev}
        if t["status"] == "done" and c != "log":
            sys.exit(f"{t['id']} уже выполнена; повторное открытие делайте через `log` и новую задачу")
        if c in ("start", "done") and approval(d, t):
            sys.exit(approval(d, t))
        if c in ("start", "done") and any(x["status"] != "done" for x in children(d, t["id"])):
            sys.exit("сначала завершите дочерние этапы")
        if c in ("done", "partial", "block", "checkpoint") and t["status"] == "in_progress" and t.get("owner") != WHO and not a.take:
            sys.exit(f"задача в работе у {t.get('owner')}")
        if c == "start":
            if t.get("coordinated_by"):
                sys.exit("начните через " + t["coordinated_by"])
            if t["status"] == "blocked" and not (a.take and a.note):
                sys.exit("для снятия блокировки укажите --take и причину в --note")
            miss = [x for x in t["deps"] if ids[x]["status"] != "done"]
            if miss:
                sys.exit("зависимости не выполнены: " + ", ".join(miss) + (f" ({t['deps_note']})" if t.get("deps_note") else ""))
            if t["status"] == "in_progress":
                if t.get("owner") == WHO:
                    sys.exit("задача уже ваша, продолжайте работу")
                if not a.take:
                    sys.exit(f"задача занята: {t.get('owner')}; чтобы забрать, укажите --take")
            t["status"] = "in_progress"
            t["owner"] = WHO
            t.setdefault("log", []).append(entry("взята в работу" + (f" ({a.note or 'перехвачена'})" if a.take else "")))
        elif c == "done":
            if not a.note:
                sys.exit("нужен --note с отчётом")
            if t["status"] not in ("in_progress", "partial"):
                sys.exit("закрывать можно задачу в работе: сначала `start`")
            miss = [x for x in t["deps"] if ids[x]["status"] != "done"]
            if miss:
                sys.exit("зависимости не выполнены: " + ", ".join(miss))
            if t.get("manual"):
                if not a.manual:
                    sys.exit("задача ручная: нужно --manual с описанием проверки (устройство, версия, результат)")
            elif not ev:
                sys.exit("нужно подтверждение: --commit ХЕШ, --ci ССЫЛКА или --manual ОПИСАНИЕ")
            t["status"] = "done"
            t["done_date"] = today()
            d["meta"]["last_completed"] = t["id"]
            t.pop("owner", None)
            t.setdefault("log", []).append({**entry("СДЕЛАНО: " + a.note), **({"tests": int(a.tests)} if a.tests else {})})
        elif c == "checkpoint":
            if t["status"] not in ("in_progress", "partial") or not a.note.strip() or not a.next.strip():
                sys.exit("checkpoint требует активной или частичной задачи, --note и --next")
            t.setdefault("log", []).append({**entry(a.note), "next": a.next})
        elif c == "partial":
            t["status"] = "partial"
            t.pop("owner", None)
            t.setdefault("log", []).append(entry("ЧАСТИЧНО: " + a.note))
        elif c == "block":
            t["status"] = "blocked"
            t.pop("owner", None)
            t.setdefault("log", []).append(entry("ЗАБЛОКИРОВАНО: " + a.note))
        else:
            t.setdefault("log", []).append(entry(a.note))
        if a.tests:
            d["meta"]["tests"] = int(a.tests)
            d["meta"]["tests_date"] = today()
    elif c == "ask":
        qs = d.setdefault("pending_decisions", [])
        qs.append({"id": (max([q["id"] for q in qs]) + 1) if qs else 1, "date": today(), "who": WHO, "wp": a.wp, "text": a.text or a.note, "status": "open"})
    elif c == "decide":
        q = next((q for q in d.get("pending_decisions", []) if str(q["id"]) == str(a.arg)), None)
        if not q:
            sys.exit("нет такого вопроса")
        q["status"] = "answered"
        q["answer"] = a.text or a.note
        q["answer_date"] = today()
        d.setdefault("journal", []).append({"date": today(), "who": WHO, "text": f"Ответ владельца на вопрос #{q['id']}: {q['answer']}"})
    elif c == "note":
        d.setdefault("journal", []).append({"date": today(), "who": WHO, "text": a.text or a.note, **({"commit": a.commit} if a.commit else {})})
    elif c == "tests":
        d["meta"]["tests"] = int(a.arg)
        d["meta"]["tests_date"] = today()
    elif c == "check":
        e = check(d) + check_links()
        if not e and Path(OUT).read_text(encoding="utf-8") != render(d, write=False):
            e.append("ROADMAP.md устарел: выполните render")
        print("OK" if not e else "\n".join(e))
        sys.exit(1 if e else 0)
    elif c == "render":
        pass
    else:
        sys.exit("неизвестная команда, см. help")
    save(d)
    render(d)
    if c == "done":
        print(report(ids[a.arg]))
    print("готово: tasks.json и ROADMAP.md обновлены")


if __name__ == "__main__":
    main()
