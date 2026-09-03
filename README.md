# Network Connection Monitor

Monitors internet connection stability and visualizes the results.

- `monitor_connection.sh` — cron script that pings the local gateway, `1.1.1.1` (Cloudflare) and `8.8.8.8` (Google) and appends the results to a CSV log.
- `network_connection_analysis.ipynb` — Jupyter notebook (micromamba base environment) that analyzes and plots the logged data.

## Monitor script

Run manually:

```bash
./monitor_connection.sh
```

Install as a cronjob (runs every minute):

```bash
crontab -e
```

Add the line:

```
* * * * * /home/jannis/Desktop/Repos/network-connection/monitor_connection.sh
```

Each run sends 3 pings per host (`-c 3 -W 1`, ~6 s total) and appends one CSV row per host. Results go to `data/connection_log.csv`. Paths, log file, ping count and timeout can be overridden via the `LOG_FILE`, `PING_COUNT` and `PING_TIMEOUT` environment variables. A lock file prevents overlapping runs.

### Log format

```
timestamp,host,label,sent,received,loss_pct,min_ms,avg_ms,max_ms
2026-09-03T17:56:12+02:00,1.1.1.1,cloudflare,3,3,0,7.001,7.106,7.268
```

| Column      | Meaning                                              |
|-------------|------------------------------------------------------|
| `timestamp` | ISO 8601 local time with UTC offset                  |
| `host`      | IP that was pinged (gateway is resolved dynamically) |
| `label`     | `gateway`, `cloudflare` or `google`                  |
| `sent`      | Pings sent this run (3)                              |
| `received`  | Pings answered (0 = host unreachable)                |
| `loss_pct`  | Packet loss in percent                               |
| `min_ms` / `avg_ms` / `max_ms` | Round-trip times in ms (empty if no reply) |

### Reading the results

- **gateway fails, public IPs ok** → local network / router problem
- **all public IPs fail, gateway ok** → ISP / modem outage
- **only one public IP fails** → issue with that provider, not your connection
- **latency spikes on public IPs with stable gateway** → congestion or routing issues

## Notebook

Requires the micromamba base environment (already contains jupyter, pandas, matplotlib, seaborn):

```bash
micromamba run -n base jupyter notebook network_connection_analysis.ipynb
```

The notebook computes availability statistics, latency time series, hourly heatmaps, outage periods and a gateway-vs-internet failure analysis.
