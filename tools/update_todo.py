import json
from pathlib import Path

path = Path(".docs/TODO.JSON")
data = json.loads(path.read_text(encoding="utf-8"))

status = {
    "NER-038": "done",
    "NER-104": "done",
    "NER-105": "done",
    "NER-106": "done",
}

for phase in data["phases"]:
    for task in phase["tasks"]:
        tid = task.get("id")
        if tid in status:
            task["status"] = status[tid]
        if tid == "NER-106":
            task["title"] = "GitHub Release, скриншоты, трейлер"
            task["acceptance"] = "Опубликован тег v0.1.0, билд, 6 скриншотов и 19-секундный трейлер."
        if tid == "NER-082":
            task["title"] = "Реплики Веры: 32, SAPI + субтитры"
        if tid == "NER-083":
            task["acceptance"] = "4 ленты озвучены, ключевая фраза в блокноте."

# Add CI task to P10 if absent.
p10 = next(p for p in data["phases"] if p["id"] == "P10")
ids = {t["id"] for p in data["phases"] for t in p["tasks"]}
if "NER-109" not in ids:
    p10["tasks"].append({
        "id": "NER-109",
        "title": "CI: headless-тесты в GitHub Actions",
        "status": "done",
        "priority": "P1",
        "area": "infra",
        "estimate_days": 1,
        "deps": ["NER-104"],
        "acceptance": "Workflow tests.yml импортирует проект и прогоняет 101 проверку на Ubuntu.",
    })

total = sum(len(p["tasks"]) for p in data["phases"])
done = sum(1 for p in data["phases"] for t in p["tasks"] if t["status"] == "done")
in_progress = sum(1 for p in data["phases"] for t in p["tasks"] if t["status"] == "in_progress")
todo = sum(1 for p in data["phases"] for t in p["tasks"] if t["status"] == "todo")
blocked = sum(1 for p in data["phases"] for t in p["tasks"] if t["status"] == "blocked")
data["summary"] = {
    "total_tasks": total,
    "done": done,
    "in_progress": in_progress,
    "todo": todo,
    "blocked": blocked,
}
data["updated"] = "2026-11-06"
path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"tasks {total}: done {done}, in_progress {in_progress}, todo {todo}, blocked {blocked}")
