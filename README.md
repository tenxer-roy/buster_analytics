# Buster_Analytics
Lab session summarizer for Raspberry pi, running on Debian Buster

## Overview  
`buster_analytics` is a shell script designed to help **electronics engineers** and **Linux users** to analyze usage logs from Raspberry Pi associated with labs that are under development & not released. This script works with **Debian Buster only** pi devices. It parses `/var/log/analytics.log` to identify user sessions, calculate durations, and flag overuse patterns.

---

## What It Does
- This script runs inside the Raspberry Pi associated with Lab Hardware
- Parses logs for `SessionStart`, `SessionEnd`, and `active_time` from `/var/log/analytics.log` file.
- Handles missing `SessionEnd` by using `SessionStart + active_time`.
- Flags sessions over 45 minutes.
- Sorts session reports by **Start Time**.
- Filters out `device_idle`, internal domains, and null users.
- Shows the result in a table in shell.
- Works on **Raspberry Pi** with **Debian buster**.

---

## Files & Versions

| Version | Description |
|--------|-------------|
| `buster_analytics_v1.sh` | Initial parsing with basic fields, handled `SessionEnd` missing and added active_time |
| `buster_analytics_v2.sh` | Added time range filtering, redundant entries |
| `buster_analytics_v3.sh` | Sorted by Start Time, deduplicated sessions |
| `buster_analytics_v4_final.sh` | Added Progress bar for easy visualization, fully cron-ready |

---

## Usage Instructions

### Manual Run
```bash
bash buster_analytics_v4_final.sh
```

### Optional Flags
| Flag | Description | Example |
|------|-------------|---------|
| `-t` | Time range in days (default: 10) | `-t 30` |
| `-f` | Custom log file path (default: /var/log/analytics.log) | `-f /home/pi/test.log` |

#### Example:
```bash
bash buster_analytics_v4_final.sh -t 14 -f /home/pi/mylog.log
```

---

## Output Format

| Email | Start Time | End Time | Duration | Notes |
|-------|------------|----------|----------|-------|
| `user1@example1.com` | `2025-07-07 12:00:00` | `2025-07-07 12:45:10` | `49m` | Over 45 min |
| `user2@example2.com` | `2025-07-11 11:06:52` | `2025-07-11 11:27:52` | `21m`| |        

---

## Cron Automation
- Create a folder first as `/home/pi/saved_analytics/` to save the results
- To schedule it every day at **6 AM** and save reports with date:

```bash
crontab -e
```

Add this line:
```cron
0 6 * * * bash /home/pi/buster_analytics_v4_final.sh > /home/pi/saved_analytics/analytics_$(date +\%Y\%m\%d).txt 2>/dev/null
```

This will save a new `.txt` file daily in `/home/pi/saved_analytics/`.

---

## Testing Cron Setup (Optional)

To test it every minute:
```cron
* * * * * bash /home/pi/buster_analytics_v4_final.sh > /home/pi/saved_analytics/test_run_$(date +\%Y\%m\%d_%H%M).txt 2>/dev/null
```

---

## Important Notes

- Make sure `analytics.log` is accessible.
- The script skips:
  - users like `device_idle`
  - emails ending in `@tenxerlabs.com` or `@kimshuka.com`
  - null or empty user names

---

## How Session Duration is Calculated

| Condition | Calculation |
|-----------|-------------|
| Has `SessionStart` + `SessionEnd` | Use difference of timestamps |
| Has `SessionStart` but missing `SessionEnd` | Add `active_time` to `SessionStart` |
| Only `active_time` present | Ignored (cannot infer session window) |

---

## Dependencies

Pure Shell: Works out of the box with `bash`, `awk`, and `date`. No need for `jq`, Python, or any external library.

---

## Notes

If you're an **electronics engineer** who’s new to Linux:
- These scripts are plug-and-play.
- You can **customize time ranges**, **change log paths**, or **auto-save reports** with cron.
- Safe to run on **Raspberry Pi**, **BeagleBone**, or any ARM/Debian device running on **Debian Buster**.

---

## Future Ideas
- Add HTML or CSV export
- Include user activity heatmaps
- Integrate with Grafana dashboards or email alerts
