# Approach, Sample-Site Justification & ITS Mapping

## 1. Protocol-level browser simulation vs real-browser

"Frontend performance testing" splits into two techniques. They answer
different questions and have very different scaling economics.

### A. Protocol-level + embedded resources  ← this framework
JMeter requests each page's HTML **and** downloads every same-domain embedded
resource (CSS, JS, images), in parallel (6 connections), with an HTTP Cache
Manager so first-time visitors pay full download cost. It follows forms,
correlates dynamic tokens, and submits exactly like a browser's network layer.

- **Validates frontend:** total page weight, number/size of assets, asset
  delivery time, cacheability, compression — the network-level frontend SLA.
- **Validates backend:** dynamic page generation, form POST handling, DB.
- **Scales:** thousands of users per generator (no browser engine per user).
- **No plugins, no browsers** → runs identically in GUI, CLI, BlazeMeter,
  RedLine13.

What it does **not** measure: client-side JavaScript execution time, DOM build,
paint/layout, Core Web Vitals (LCP/CLS/INP). Those are *browser-render* metrics.

### B. Real-browser (Selenium / Playwright)
Drives an actual browser that renders and executes JS, so it captures true
client render timing — but each browser instance needs roughly **1 CPU + ~1 GB
RAM**, so a single host runs tens, not thousands. It needs the WebDriver Sampler
plugin (or a separate tool) and browser binaries on every generator.

### Why this framework uses A
Your requirements — **1000+ concurrent users, across GUI/CLI/BlazeMeter/
RedLine13, with no plugins** — can only be met by protocol-level testing. It is
the industry-standard way to load-test a web frontend at scale. Use a small
real-browser run (5–20 users) **alongside** it when you also need client render
metrics; the two are complementary, not substitutes.

> Rule of thumb: protocol-level answers *"does the site stay fast and correct
> under N users?"*; real-browser answers *"how fast does the page paint for one
> user?"*. ITS promo-scale capacity planning is the former.

---

## 2. Why BlazeDemo is the right sample site

`https://blazedemo.com` is a public, stable, **server-rendered** multi-step
booking app — purpose-built by BlazeMeter for exactly this kind of demo. It
exercises every capability the ITS framework needs:

| Capability needed for ITS | BlazeDemo provides |
|---|---|
| Multi-page real-user journey | landing → reserve → purchase → confirmation |
| City/option selection | `fromPort` / `toPort` dropdowns → `POST /reserve.php` |
| Seat/zone-style selection from a list | flight table, each row a form → `POST /purchase.php` |
| Registration / data-entry form | passenger form (name/address/card) → `POST /confirmation.php` |
| Dynamic correlation | each flight row carries `flight`/`price`/`airline` hidden fields |
| Embedded frontend assets | Bootstrap CSS/JS + jQuery → real page weight |
| Positive assertions | distinct page-content anchors per step |
| Free & safe to load | public demo, no auth, no licensing |

A pure SPA/AJAX demo (e.g. demoblaze.com) would have turned this back into API
testing (its pages are JSON calls). BlazeDemo's server-rendered HTML forms make
it a genuine **page-load** workload — the point of this framework.

---

## 3. ITS page mapping

| Framework transaction | BlazeDemo | ITS page |
|---|---|---|
| `TX_01_Open_Landing_CitySelection` | `GET /` | Promo landing / **city selection** |
| `TX_02_Select_City` | `POST /reserve.php` | **Seat/zone selection** list |
| `TX_03_Select_Flight_Seat` (competitive) | `POST /purchase.php` | Seat chosen → **registration** form |
| `TX_04_Register_Confirm` | `POST /confirmation.php` | Confirm / book |

**Adding ITS's separate "zone selection" step:** copy any transaction block,
point it at the ITS zone page, add its correlation/assertions, and insert it
between city and seat. The generator (`scripts/generate-plans.ps1`) then
propagates it to every load profile automatically.

---

## 4. The competitive-burst model

Real promo traffic isn't smooth — at the on-sale instant, thousands hit
seat-selection together. A **Synchronizing Timer** on `TX_03` holds arriving
threads and releases them as one wave (`sync_group_size`), with a safety
`sync_timeout` so ramp-up never deadlocks. This reproduces seat-contention and
lock/queue behaviour on the backend that smooth load would hide. Set
`sync_group_size` to your cohort size on BlazeMeter/RedLine13 to storm the
seat-selection endpoint.
