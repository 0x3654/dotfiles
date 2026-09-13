#!/usr/bin/env python3
"""Регистрация скопированного каталога расширения в ~/.cursor/extensions/extensions.json.

Использование: register.py <каталог_расширения>

Читает package.json (publisher.name, version), строит запись в формате
extensions.json (как их пишет сам Cursor) и добавляет, если id отсутствует.
Для расширений, которых нет в gallery Cursor (например codesnap-plus).
"""
import json
import os
import sys

ext_dir = sys.argv[1].rstrip("/")
pkg = json.load(open(os.path.join(ext_dir, "package.json"), encoding="utf-8"))
ext_id = f"{pkg['publisher']}.{pkg['name']}"
version = pkg["version"]

ext_root = os.path.dirname(ext_dir)
index_path = os.path.join(ext_root, "extensions.json")

data = json.load(open(index_path, encoding="utf-8")) if os.path.exists(index_path) else []
if any(e["identifier"]["id"] == ext_id for e in data):
    print(f"unchanged {ext_id}")
    sys.exit(0)

rel = os.path.basename(ext_dir)
data.append(
    {
        "identifier": {"id": ext_id},
        "version": version,
        "location": {"$mid": 1, "path": ext_dir, "scheme": "file"},
        "relativeLocation": rel,
        "metadata": {
            "isApplicationScoped": False,
            "isMachineScoped": False,
            "isBuiltin": False,
            "installedTimestamp": 0,
            "pinned": False,
            "source": "gallery",
            "id": pkg.get("uuid", ""),
            "publisherId": "",
            "publisherDisplayName": pkg["publisher"],
            "targetPlatform": "universal",
            "updated": False,
            "private": False,
            "isPreReleaseVersion": False,
            "hasPreReleaseVersion": False,
            "preRelease": False,
        },
    }
)
json.dump(data, open(index_path, "w", encoding="utf-8"))
print(f"registered {ext_id}@{version}")
