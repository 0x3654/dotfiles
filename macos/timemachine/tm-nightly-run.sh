#!/bin/sh
# Обёртка ночного запуска Time Machine: не «попытались и ушли», а «добились записи».
# moro на Wi-Fi (кабель невозможен): копия может умереть по эфиру в любой момент,
# поэтому после каждой попытки проверяем запись за сегодня и повторяем
# (до 4 попыток с интервалом 30 минут). caffeinate -s страхует от сна системы.
PATH=/usr/bin:/bin:/usr/sbin:/sbin
LOG=/var/log/tm-nightly.log

have_today() {
    /usr/bin/tmutil listbackups 2>/dev/null | grep -q "$(date +%F)-"
}

i=0
while [ "$i" -lt 4 ]; do
    echo "== $(date '+%F %T') попытка $((i+1))" >> "$LOG"
    /usr/bin/caffeinate -s /usr/bin/tmutil startbackup --block >/dev/null 2>&1
    if have_today; then
        echo "== $(date '+%F %T') OK: запись за $(date +%F) есть" >> "$LOG"
        exit 0
    fi
    echo "== $(date '+%F %T') попытка $((i+1)) не дала записи" >> "$LOG"
    i=$((i+1))
    [ "$i" -lt 4 ] && sleep 1800
done
echo "== $(date '+%F %T') все попытки исчерпаны" >> "$LOG"
exit 1
