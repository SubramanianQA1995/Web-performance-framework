# BlazeMeter & RedLine13 Deployment (Web Framework)

The web plans follow the same cloud-safe rules proven on the API framework.

## 1. What to upload
- The chosen plan, e.g. `jmx/LoadTest.jmx`.
- **Both** data files: `data/routes.csv` **and** `data/userdata.csv`.

Both CSV Data Sets reference files by **filename only** (`routes.csv`,
`userdata.csv`) via `${__P(routes_file,routes.csv)}` /
`${__P(userdata_file,userdata.csv)}`. BlazeMeter and RedLine13 flatten every
uploaded file into one directory next to the JMX, so filename-only resolves
correctly. **Never** use `../data/...` here — that path doesn't exist on the
cloud engine (the exact bug we hit on the API project).

## 2. JMeter Properties to set (per run)
Set these in BlazeMeter's *JMeter Properties* (Configuration) or RedLine13's
*JMeter Properties* box. All have defaults baked in — only override what differs.

```
# target
base_url=blazedemo.com
protocol=https
port=443
embedded_url_re=^https?://(www\.)?blazedemo\.com/.*
# data (filename only)
routes_file=routes.csv
userdata_file=userdata.csv
# load
users=200
rampup=120
duration=900
think_time_min=2000
think_time_range=5000
# competitive on-sale burst (seat selection)
sync_group_size=200
sync_timeout=60000
```

> `users` is **per generator**. Total VUs = users × generators. For page-weight
> load, prefer more generators with fewer threads each (keep generator CPU < 75%).

## 3. "Register / select seat — 1000 users at once"
To reproduce the flash on-sale where everyone hits seat selection together:
1. Total threads across generators ≥ 1000 (e.g. 5 generators × 200).
2. `sync_group_size=1000` and `sync_timeout=60000`.
The Synchronizing Timer on `TX_03_Select_Flight_Seat` gathers the cohort and
releases them simultaneously against the seat endpoint. Keep `sync_group_size`
≤ total threads or the group never fills (the timeout then releases it anyway,
but you lose the clean burst).

## 4. embedded_url_re on cloud
Keep it scoped to the **app's own asset domains** so you measure your frontend,
not third-party CDNs. For ITS, set it to ITS's static/asset hosts, e.g.:
```
embedded_url_re=^https?://(.*\.)?its\.company\.com/.*|^https?://cdn\.its\.company\.com/.*
```

## 5. RedLine13 architecture & scaling
Identical model to the API framework — see
`../../PerformanceFramework/docs/RedLine13-Guide.md` for the controller /
load-generator / agent / multi-region diagrams and AWS setup. **One adjustment
for web:** because each thread downloads full page weight, budget **fewer
threads per generator** than the API table (start ~40–60% of those numbers) and
watch generator CPU/network — add generators rather than threads.

## 6. Collect results
Download the aggregated JTL and regenerate the full percentile dashboard locally:
```bash
jmeter -g results/<downloaded>.jtl -o reports/<run-id>
```
