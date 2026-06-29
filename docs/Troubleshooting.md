# Web Framework — Troubleshooting

## Built-in debugging aids
- **Debug Sampler** (`DBG - Variables Snapshot`) shows `fromPort`, `toPort`,
  `flightsel_g1/g2/g3`, and CSV row values per iteration.
- **Transaction names** (`TX_01..TX_04`) sort cleanly in the dashboard.
- **Regex Extractor default** `EXTRACT_FAILED` makes correlation misses obvious.
- **Custom assertion messages** on landing and confirmation explain failures.

### Verbose local debug
Open in GUI → enable **View Results Tree** → run 1 user → expand a page
transaction to see the main request **and its embedded sub-results** (each
CSS/JS/image) → disable View Results Tree before load.

## Common issues

| Symptom | Cause | Fix |
|---|---|---|
| `routes.csv`/`userdata.csv` must exist and be readable | Path not flat / not uploaded | Use filename-only (default). Locally run via the scripts (they pass abs paths); on cloud upload **both** CSVs next to the JMX. Never `../data/...`. |
| `flightsel_g1 = EXTRACT_FAILED` / seat step 4xx | Reserve page markup changed or city has no flights | Check `POST /reserve.php` response; confirm the Regex matches `value="N" name="flight"`; verify the city pair returns flights. |
| Page transaction much slower than its main request | That's correct — transaction = HTML **+** all embedded assets | Expand sub-results to find the slow asset; this is the frontend signal you want. |
| External CDN assets inflating page time | `embedded_url_re` too broad | Scope it to your app domains only (it already excludes googleapis on BlazeDemo). |
| Test hangs at a step | Synchronizing Timer group never fills | Ensure `sync_group_size` ≤ total threads; rely on `sync_timeout` to auto-release; set `sync_group_size=1` to disable. |
| Assertion fails on `Welcome to the Simple Travel Agency` etc. | Wrong base_url, redirect, or the target application migration | Confirm `base_url`/`protocol`/`port`; update assertion anchors to the target page text when migrating. |
| Embedded resources cause `Non HTTP response`/timeouts at scale | Generator network saturation | Fewer threads/generator, more generators; raise `response_timeout`. |
| OutOfMemory on generator | Page weight × threads too high | Raise heap (`HEAP="-Xms1g -Xmx4g"`); response data already off; reduce threads. |
| Form POST rejected (missing field) | A hidden/required field not sent | Compare against the live form; add the missing `HTTPArgument` (forms are field-sensitive). |

## Regenerate dashboard from any JTL
```bash
jmeter -g results/<run-id>/results.jtl -o reports/<run-id>
```

## Quick 1-user sanity check
```bash
jmeter -n -t jmx/SmokeTest.jmx -Jsmoke_users=1 -Jsmoke_loops=1 \
  -q config/env/qa.properties \
  -Jroutes_file=data/routes.csv -Juserdata_file=data/userdata.csv \
  -l results/sanity.jtl -j results/sanity.log
```
