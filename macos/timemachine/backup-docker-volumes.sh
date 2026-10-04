#!/bin/sh
# Ночной экспорт именованных docker-томов в обычные файлы (tar+gzip),
# чтобы Time Machine бэкапил их как данные, а не полз по Docker.raw
# (единый VM-диск Docker Desktop: 1.8T логических, TM не умеет sparse).
# Запуск launchd-агентом com.user.backup-docker-volumes в 00:30, до слота TM 01:00.
# pg1c НЕ дампится тут — его дампы уже идут в ~/code/_bd_backup (pg_dump в контейнере).
set -eu

DEST="${HOME}/backups/docker-volumes"
KEEP=7
SKIP_RE='gomod|gocache|playwright|dev-cache|_data$|pg1c-data$'
# pg1c-data$ — живой PG стенда дампится nightly в ~/code/_bd_backup
# (pg_dump в контейнере), тар живого PG неконсистентен и избыточен

mkdir -p "$DEST"
STAMP=$(date +%F)

for vol in $(docker volume ls --format '{{.Name}}' | grep -vE '^[0-9a-f]{64}$'); do
    echo "$vol" | grep -qE "$SKIP_RE" && continue
    out="$DEST/${STAMP}-${vol}.tgz"
    [ -s "$out" ] && continue
    tmp="$out.part"
    if docker run --rm -v "$vol:/src:ro" -v "$DEST:/dst" alpine:3.20 \
         tar czf "/dst/$(basename "$tmp")" -C /src . 2>/dev/null; then
        mv "$tmp" "$out"
        echo "ok: $vol -> $(du -h "$out" | cut -f1)"
    else
        rm -f "$tmp"
        echo "FAIL: $vol" >&2
    fi
done

# ротация: по KEEP свежих архивов на том
ls "$DEST" | sed 's/^[0-9-]*-//' | sort -u | while read -r v; do
    ls -t "$DEST"/*-"$v".tgz 2>/dev/null | tail -n +$((KEEP + 1)) | while read -r f; do
        rm -f "$f"
    done
done
