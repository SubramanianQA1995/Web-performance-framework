# Web Framework — Execution Guide

Three tiers: **Local**, **BlazeMeter/RedLine13 (cloud)**, **Production-scale**.

## Prerequisites
- Apache JMeter (latest) + Java 17+ (Java 8 also fine on cloud engines).
- On PATH, or set `JMETER_HOME` and `JAVA_HOME` (the runner scripts honour them):
  ```powershell
  $env:JAVA_HOME="C:\Tools\jdk-26.0.1"; $env:JMETER_HOME="C:\Tools\apache-jmeter-5.6.3"
  $env:PATH="$env:JAVA_HOME\bin;$env:JMETER_HOME\bin;$env:PATH"
  ```

## A. Local

### GUI (edit/debug only)
1. `File → Open` → `jmx/SmokeTest.jmx`.
2. Temporarily enable **View Results Tree**.
3. The two CSV Data Sets default to filename-only — for GUI, either copy
   `routes.csv`/`userdata.csv` into JMeter's `bin/`, or set
   `-Jroutes_file=`/`-Juserdata_file=` to absolute paths, or just use the CLI
   runner (recommended).
4. Run, inspect the journey, then **disable** View Results Tree.

### CLI (the real way)
```powershell
.\scripts\run-test.ps1 -Plan SmokeTest -Env qa
.\scripts\run-test.ps1 -Plan EndToEndJourney -Env qa
.\scripts\run-test.ps1 -Plan LoadTest -Env qa -Props @{users=20; rampup=30; duration=180}
```
```bash
./scripts/run-test.sh SmokeTest qa
./scripts/run-test.sh LoadTest  qa -Jusers=20 -Jrampup=30 -Jduration=180
```
The scripts pass both CSV absolute paths and generate the HTML dashboard at
`reports/<run-id>/index.html`.

> Page-weight load (embedded resources) is heavier per thread than API load —
> a laptop sustains far fewer web threads than API threads. Keep local runs
> small; scale on the cloud.

## B. BlazeMeter / RedLine13
See [`BlazeMeter-RedLine13.md`](BlazeMeter-RedLine13.md). Key point: upload the
JMX **and both CSVs** (`routes.csv`, `userdata.csv`); set load + `embedded_url_re`
+ `sync_group_size` via the platform's JMeter Properties box. No file edits.

## C. Production-scale (promo on-sale rehearsal)
1. Cloud generators sized for page-weight load (fewer threads/generator than API).
2. Set the competitive burst: `sync_group_size` = cohort size, `sync_timeout`
   generous (e.g. 60000).
3. Ramp realistically (≥ 5 min for 10k+), watch BlazeMeter live + your APM.
4. Expand `userdata.csv`/`routes.csv` so users don't collide unrealistically.
5. Scope `embedded_url_re` to the target application asset domains/CDNs you own.

## Reading results
HTML dashboard surfaces **TPS, error %, avg, P90/P95/P99, throughput**. Because
sub-results are saved, expand a page transaction to see **per-asset timing** —
that's how you find the slow CSS/JS/image dragging down page load.
