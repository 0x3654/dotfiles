#!/bin/sh
# Обёртка ночного запуска Time Machine: добиваться записи ТОЛЬКО внутри ночи.
# Уроки 10.2026:
#  - startbackup --block привязывает бэкап к клиенту (лок/чих убивают обе) —
#    старт отсоединённый, plain startbackup;
#  - окно по СЧЁТЧИКУ попыток гнало копии до 13:48 (26.10) — теперь жёсткая
#    граница по часам: переклики только до 05:00, днём никогда;
#  - have_today слепа без FDA для /usr/bin/tmutil (listbackups блокирован
#    TCC) — потому граница по часам обязательна, FDA-выдача желательна.
# Идущая копия при закрытии окна НЕ убивается: старт отсоединённый, backupd
# доедет сам (или умрёт — следующий слот подхватит).
PATH=/usr/bin:/bin:/usr/sbin:/sbin
LOG=/var/log/tm-nightly.log
END_HOUR=5

have_today() {
    /usr/bin/tmutil listbackups 2>/dev/null | grep -q "$(date +%F)-"
}

running() {
    /usr/bin/tmutil status 2>/dev/null | grep -q 'Running = 1'
}

while [ "$(date +%H)" -lt "$END_HOUR" ]; do
    if have_today; then
        echo "== $(date '+%F %T') OK: запись за $(date +%F) есть" >> "$LOG"
        exit 0
    fi
    if ! running; then
        echo "== $(date '+%F %T') старт попытки" >> "$LOG"
        /usr/bin/tmutil startbackup >/dev/null 2>&1
        sleep 120
    else
        echo "== $(date '+%F %T') копия идёт, ждём" >> "$LOG"
    fi
    sleep 1800
done
echo "== $(date '+%F %T') ночное окно закрылось (05:00) без подтверждённой записи" >> "$LOG"
exit 1
