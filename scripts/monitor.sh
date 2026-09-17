#!/usr/bin/env bash
# Modul 5: periodisk ressourceovervågning. Køres af cron (se nixos/modules/monitoring.nix).
# Logger CPU-, disk- og hukommelsesforbrug til en central logfil, og skriver en ALERT-linje
# hvis diskforbrug eller hukommelsesforbrug overstiger de definerede tærskelværdier.
set -euo pipefail

readonly LOGFILE="/var/log/monitor.log"
readonly DISK_THRESHOLD=85  # procent
readonly MEM_THRESHOLD=90   # procent

timestamp() {
  date '+%Y-%m-%d %H:%M:%S'
}

log() {
  echo "$(timestamp) $*" >> "$LOGFILE"
}

get_cpu_usage() {
  # CPU-forbrug findes ikke som et øjebliksbillede i /proc/stat, kun akkumulerede jiffies
  # siden boot. Derfor tages to målinger med 1 sekunds mellemrum, og forbruget beregnes
  # som andelen af det tidsrum, der IKKE var idle.
  local line1 line2
  local -a f1 f2
  line1=$(grep '^cpu ' /proc/stat)
  sleep 1
  line2=$(grep '^cpu ' /proc/stat)
  read -r -a f1 <<< "$line1"
  read -r -a f2 <<< "$line2"

  # felt 0 er teksten "cpu"; felt 4 er idle, felt 5 er iowait (tælles begge som ledig tid)
  local idle1=$(( f1[4] + f1[5] ))
  local idle2=$(( f2[4] + f2[5] ))
  local total1=0 total2=0 i
  for i in 1 2 3 4 5 6 7; do
    total1=$(( total1 + f1[i] ))
    total2=$(( total2 + f2[i] ))
  done

  local totald=$(( total2 - total1 ))
  local idled=$(( idle2 - idle1 ))
  if (( totald <= 0 )); then
    echo 0
  else
    echo $(( (totald - idled) * 100 / totald ))
  fi
}

get_disk_usage() {
  df --output=pcent / | tail -1 | tr -dc '0-9'
}

get_mem_usage() {
  free | awk '/^Mem:/ { printf "%d", ($2-$7)*100/$2 }'
}

main() {
  local cpu disk mem
  cpu=$(get_cpu_usage)
  disk=$(get_disk_usage)
  mem=$(get_mem_usage)

  log "CPU=${cpu}% DISK=${disk}% MEM=${mem}%"

  if (( disk > DISK_THRESHOLD )); then
    log "ALERT: diskforbrug ${disk}% overstiger tærskel på ${DISK_THRESHOLD}%"
  fi

  if (( mem > MEM_THRESHOLD )); then
    log "ALERT: hukommelsesforbrug ${mem}% overstiger tærskel på ${MEM_THRESHOLD}%"
  fi
}

main "$@"
