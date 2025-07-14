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

# Count total lines for progress bar
TOTAL_LINES=$(wc -l < "$LOG_FILE")
PROGRESS_STEP=$((TOTAL_LINES / 100))
[ "$PROGRESS_STEP" -eq 0 ] && PROGRESS_STEP=1

awk -v start_epoch="$START_EPOCH" -v total="$TOTAL_LINES" -v step="$PROGRESS_STEP" '
function extract(str, key,    m, pattern) {
  pattern = "\"" key "\": *\\\"?([^,\\\"]+)"
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
  h = int(sec / 3600)
  m = int((sec % 3600) / 60)
  s = int(sec % 60)
  return (h > 0 ? h "h " : "") (m > 0 ? m "m " : "") (s > 0 ? s "s" : "")
}
function update_progress(current, total, last_p) {
  percent = int((current / total) * 100)
  if (percent > last_p) {
    bar = "["
    for (i = 0; i < percent; i += 2) bar = bar "#"
    for (; i < 100; i += 2) bar = bar "-"
    bar = bar "]"
    printf("\rProcessing log: %3d%% %s", percent, bar) > "/dev/stderr"
    fflush("/dev/stderr")
    return percent
  }
  return last_p
}
BEGIN {
  FS=""
  session_id = 0
  last_percent = 0
}
{
  last_percent = update_progress(NR, total, last_percent)
  ts = extract($0, "@timestamp")
  ts_epoch = to_epoch(ts)
  if (ts == "" || ts_epoch < start_epoch) next

  msg_start = index($0, "\"message\":\"{")
  if (msg_start == 0) next

  msg = substr($0, msg_start + 10)
  gsub(/\\"/, "\"", msg)
  gsub(/"$/, "", msg)

  user = extract(msg, "user_name")
  uuid = extract(msg, "uuid")
  label = extract(msg, "stack_label")
  active = extract(msg, "active_time")

  if (user ~ /@tenxerlabs.com$|@kimshuka.com$|^device_idle$|^null$/) next
  if (user == "" || uuid == "") next

  if (label == "SessionStart") {
    session_id++
    key = session_id
    start[key] = ts
    start_epoch_map[key] = ts_epoch
    user_map[key] = user
    uuid_map[key] = uuid
    active_map[key] = 0
  } else if (label == "SessionEnd") {
    for (i = session_id; i >= 1; i--) {
      if (uuid_map[i] == uuid && !(i in end)) {
        end[i] = ts
        break
      }
    }
  } else if (active != "") {
    for (i = session_id; i >= 1; i--) {
      if (uuid_map[i] == uuid && (i in start)) {
        active_map[i] += active
        break
      }
    }
  }
}
END {
  print "" > "/dev/stderr"
  for (i = 1; i <= session_id; i++) {
    s = start[i]
    user = user_map[i]
    sepoch = to_epoch(s)
    e = (i in end) ? end[i] : "Missing"
    eeepoch = (e == "Missing") ? sepoch + int(active_map[i]) : to_epoch(e)
    dur = eeepoch - sepoch

    if (dur < 0 || dur < 60) continue

    notes = ""
    if (e == "Missing") notes = "SessionEnd missing"
    if (dur > 2700) notes = (notes ? notes "; " : "") "Over 45 min"

    dur_fmt = format_duration(dur)
    printf "%-30s %-20s %-20s %-10s %s\n", user, s, e, dur_fmt, notes
  }
}' "$LOG_FILE"
