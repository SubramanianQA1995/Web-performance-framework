# ITS — Web / Application-Level Performance Testing Framework

![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)
![Apache JMeter](https://img.shields.io/badge/Apache%20JMeter-5.6.3-D22128?logo=apachejmeter&logoColor=white)
![Java](https://img.shields.io/badge/Java-17%2B-007396?logo=openjdk&logoColor=white)
![No Plugins](https://img.shields.io/badge/plugins-none-success)
![CI](https://github.com/SubramanianQA1995/its-web-performance-framework/actions/workflows/perf-tests.yml/badge.svg)

A reusable JMeter framework for **application-level (real-user, browser-style)**
performance testing — the companion to the API-level framework in
`../PerformanceFramework`. It drives a complete multi-page customer journey
the way a real visitor does (open landing → select city → select seat →
register/confirm), downloading every page asset, so it validates **both the
frontend (page-load weight & asset delivery) and the backend (form processing,
DB)** at scale.

Built on the public **BlazeDemo** site (`https://blazedemo.com`); swap in ITS
pages by changing config only. Runs in **GUI, CLI, BlazeMeter, and RedLine13**.

> **No third-party plugins. No custom Java. No external JARs.** Standard JMeter
> components only — verified end-to-end against the live site.

---

## 1. Approach: why protocol-level browser simulation

There are two ways to load-test a frontend:

| Approach | Measures | Scales to 1000s? | Plugins? | Used here |
|---|---|---|---|---|
| **Protocol-level + embedded resources** (this framework) | Full page weight (HTML+CSS+JS+images) **and** server processing | ✅ Yes | ❌ None | ✅ |
| Real-browser (Selenium/Playwright) | Client JS/paint/DOM timing | ❌ ~1 CPU per browser | ⚠️ WebDriver plugin + browsers | Complement only |

For **1000+ concurrent users across GUI/CLI/BlazeMeter/RedLine13 with no
plugins**, protocol-level is the only approach that fits — and it's the
industry standard for scaled web load testing. Each page request also pulls all
same-domain CSS/JS/images (JMeter's *Retrieve All Embedded Resources*, 6
parallel downloads, with an HTTP Cache Manager modelling first-time visitors),
so the measured "page time" reflects true frontend delivery, not just the HTML.

See [`docs/Approach.md`](docs/Approach.md) for the full rationale, the BlazeDemo
justification, the ITS page mapping, and where real-browser testing fits.

---

## 2. The user journey (maps directly to ITS)

| # | Transaction | HTTP | BlazeDemo page | ITS equivalent |
|---|---|---|---|---|
| 1 | `TX_01_Open_Landing_CitySelection` | `GET /` | landing w/ city dropdowns | landing / **city selection** |
| 2 | `TX_02_Select_City` | `POST /reserve.php` | flight list | **seat/zone selection** list |
| 3 | `TX_03_Select_Flight_Seat` | `POST /purchase.php` | passenger form | seat chosen → **registration** form |
| 4 | `TX_04_Register_Confirm` | `POST /confirmation.php` | confirmation | confirm / book |

- **Correlation:** a Regex Extractor pulls a **random** flight's
  `flight`/`price`/`airline` from the reserve page (`flightsel_g1/g2/g3`) — so
  each virtual user picks a different seat (realistic contention), and the
  values flow forward into purchase + confirmation.
- **Parameterization:** two CSV Data Sets — `routes.csv` (city pairs) and
  `userdata.csv` (registration details).
- **Assertions per page:** HTTP 200 + a page-content anchor (e.g. *"Welcome to
  the Simple Travel Agency"*, *"Choose This Flight"*, *"Thank you for your
  purchase"*) + a Duration (SLA) assertion.

---

## 3. Competitive / "N users at once" bursts

A **Synchronizing Timer** sits on the seat-selection step (`TX_03`). It gathers
threads and releases them **simultaneously**, simulating a flash on-sale where
everyone grabs a seat at the same instant.

- Controlled by `sync_group_size` (default `1` = off) and `sync_timeout`
  (releases the group anyway if it doesn't fill — prevents hangs during ramp).
- To make 1000 users hit seat-selection together:
  `-Jsync_group_size=1000 -Jsync_timeout=60000` (keep `sync_group_size` ≤ total
  threads). The **SpikeTest** plan + `perf` env are pre-wired for this.

---

## 4. Folder structure

```
WebPerformanceFramework/
├── config/
│   ├── user.properties              # engine + dashboard tuning
│   ├── environment.properties       # active/default env
│   └── env/{dev,qa,uat,perf,prod}.properties
├── data/
│   ├── routes.csv                   # city pairs (city selection)
│   └── userdata.csv                 # registration form data
├── jmx/
│   ├── SmokeTest.jmx                # source of the shared journey
│   ├── EndToEndJourney.jmx          # generated (1 user, thorough)
│   ├── LoadTest.jmx                 # generated (steady)
│   ├── StressTest.jmx               # generated (4 staged groups)
│   ├── SpikeTest.jmx                # generated (baseline + 2 bursts)
│   └── SoakTest.jmx                 # generated (long steady)
├── scripts/{run-test.ps1, run-test.sh, generate-plans.ps1}
├── ci-cd/{Jenkinsfile, azure-pipelines.yml, github-actions-perf.yml}
├── docs/{Approach.md, Execution-Guide.md, BlazeMeter-RedLine13.md, Troubleshooting.md}
├── reports/  results/  README.md
```

---

## 5. Execution

**Local (Windows):**
```powershell
.\scripts\run-test.ps1 -Plan SmokeTest -Env qa
.\scripts\run-test.ps1 -Plan LoadTest  -Env qa -Props @{users=20; rampup=30; duration=180}
# competitive burst:
.\scripts\run-test.ps1 -Plan SpikeTest -Env qa -Props @{spike2_users=100; sync_group_size=100; sync_timeout=30000}
```

**Local (Linux/CI):**
```bash
chmod +x scripts/run-test.sh
./scripts/run-test.sh SmokeTest qa
./scripts/run-test.sh LoadTest  qa -Jusers=20 -Jrampup=30 -Jduration=180
```

**Set `JAVA_HOME` + `JMETER_HOME` first** if they're not on PATH (the scripts honour them). GUI mode is for editing/debug only — never drive load from the GUI.

Outputs: `results/<run-id>/results.jtl` and the **HTML dashboard** at
`reports/<run-id>/index.html` (TPS, error %, avg, **P90/P95/P99**, throughput,
plus per-asset sub-results so you can see which resource is slow).

---

## 6. BlazeMeter & RedLine13

Same packaging rules as the API framework (learned the hard way): **CSV files
are referenced by filename only** (`routes.csv`, `userdata.csv`) so they resolve
in the flat upload directory. Upload the JMX **plus both CSVs**, and set load
via the platform's JMeter Properties box. Full steps, the property list, and the
"register 1000 at once" cloud recipe are in
[`docs/BlazeMeter-RedLine13.md`](docs/BlazeMeter-RedLine13.md).

---

## 7. Migrating to ITS

Change config only — not structure:

1. `base_url`, `protocol`, `port`, `embedded_url_re` → ITS host/domain.
2. Sampler **paths + form fields** → ITS pages (keep the 4-transaction shape;
   add a 5th, e.g. a separate *zone selection* page, by copying a transaction).
3. **Correlation** → update the Regex Extractor to ITS hidden fields / CSRF
   tokens (the pattern is already there).
4. CSV columns → ITS registration + selection data.
5. SLA/assertion anchors → ITS page text + ITS page-time targets.

The reusable components, embedded-resource handling, competitive-burst timer,
reporting, CI/CD, and cloud packaging stay identical.
