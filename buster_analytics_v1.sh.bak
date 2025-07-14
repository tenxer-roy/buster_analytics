#!/bin/bash

DAYS=10
LOG_FILE="/var/log/analytics.log"

while getopts "t:f:" opt; do
  case $opt in
    t) DAYS="$OPTARG" ;;
    f) LOG_FILE="$OPTARG" ;;
    *) echo "Usage: $0 [-t days] [-f log_file]"; exit 1 ;;
  esac
done

if [ ! -f "$LOG_FILE" ]; then
  echo "Log file not found: $LOG_FILE"
  exit 1
fi

START_EPOCH=$(date -d "-$DAYS days" +%s)

# Header
printf "%-30s %-20s %-20s %-10s %s\n" "Email" "Start Time" "End Time" "Duration" "Notes"

# Parse
awk -v start_epoch="$START_EPOCH" '
function extract(str, key,    m) {
  pattern = "\"" key "\": *\"?([^,\"]+)\"?"
  return (match(str, pattern, m)) ? m[1] : ""
}
function to_epoch(ts,   cmd, result) {
  gsub("T", " ", ts)
  cmd = "date -d \"" ts "\" +%s"
  cmd | getline result
  close(cmd)
  return result
}
function format_duration(sec,   h, m, s) {
  h = int(sec/3600); m = int((sec%3600)/60); s = int(sec%60)
  return (h > 0) ? h "h " m "m" : (m > 0) ? m "m" : s "s"
}
BEGIN {
  FS=""
}
{
  line = $0
  ts = extract(line, "@timestamp")
  ts_epoch = to_epoch(ts)

  if (ts == "" || ts_epoch < start_epoch) next

  msg_start = index(line, "\"message\":\"{")
  if (msg_start == 0) next

  msg = substr(line, msg_start + 10)
  gsub(/\\"/, "\"", msg)
  gsub(/"$/, "", msg)

  user = extract(msg, "user_name")
  uuid = extract(msg, "uuid")
  label = extract(msg, "stack_label")
  active = extract(msg, "active_time")

  if (user ~ /@tenxerlabs.com$|@kimshuka.com$|^device_idle$|^null$/) next
  if (user == "" || uuid == "") next

  key = uuid

  if (label == "SessionStart") {
    start[key] = ts
    user_map[key] = user
    active_map[key] = 0
  } else if (label == "SessionEnd") {
    end[key] = ts
  } else if (active != "") {
    active_map[key] += active
  }
}
END {
  PROCINFO["sorted_in"] = "@ind_str_asc"
  for (key in start) {
    s = start[key]
    e = (key in end) ? end[key] : "Missing"
    sepoch = to_epoch(s)
    eeepoch = (e == "Missing") ? sepoch + int(active_map[key]) : to_epoch(e)
    dur = eeepoch - sepoch

    notes = ""
    if (e == "Missing") notes = "SessionEnd missing"
    if (dur > 2700) notes = (notes ? notes "; " : "") "Over 45 min"

    dur_fmt = format_duration(dur)
    printf "%-30s %-20s %-20s %-10s %s\n", user_map[key], s, e, dur_fmt, notes
  }
}' "$LOG_FILE"
