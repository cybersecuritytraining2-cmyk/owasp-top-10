# Vault Street Bank — OWASP A01: Broken Access Control (+ Injection & Mass Assignment)

A deliberately vulnerable online-banking application built to teach **OWASP Top 10
A01:2021 — Broken Access Control**. You will log in as an ordinary customer and
use the application's own features to access money and data that should never be
yours.

It also carries two further, deliberately planted server-side flaws on the
**“Open a new account”** feature so you can contrast bug classes under tooling:

- **Server-Side Template Injection (SSTI → RCE)** — A03:2021 Injection.
- **Mass Assignment** — A08:2021 Software & Data Integrity Failures / the OWASP
  API Top 10 *Broken Object Property Level Authorization*.

The contrast is the point: the access-control flaws are invisible to a SAST scan,
while the injection and mass-assignment flaws light it up.

> ⚠️ **Training use only.** This app ships with intentional vulnerabilities, weak
> secrets, and seeded personal data. Never deploy it anywhere reachable from the
> internet.

---

## The application

**Vault Street Bank** is a small retail-banking portal. Once signed in, a
customer can:

- See their **checking balance**, **account number**, and **credit card** (number, limit, balance owed).
- View their **statement** (transaction history).
- **Transfer money** to another customer by account number.
- **Pay down their credit card** from one of their accounts.
- **Open a new account** by giving it a nickname (it opens with a $0.00 balance
  and shows a personalized welcome banner).

There are three demo customers. Their credentials are shown right on the login
screen:

| Username | Password      | Account     |
|----------|---------------|-------------|
| `alice`  | `Spring2024!` | `5021-0001` |
| `bob`    | `Hunter2024#` | `5021-0002` |
| `carol`  | `Autumn2024$` | `5021-0003` |

---

## Running it

```bash
# First time — installs Ruby gems and npm packages
./install.sh

# Every time after that
./start.sh
#   Backend  → http://localhost:3000
#   Frontend → http://localhost:5173
```

Open **http://localhost:5173** and sign in. State is held in memory only — restart
the backend to reset every balance, statement, and block back to the seed data.

There is a floating **“?” Hint button** in the bottom-right of every screen if you
get stuck.

---

## Your objectives

The core of this exercise is **access control** — the app authenticates you fine,
but it is sloppy about checking *what you are allowed to do* once you are in. Two
bonus objectives (4 and 5) cover injection and mass assignment on the new
**“Open a new account”** feature. Sign in as **Alice** and try to achieve each of
the following:

1. **Pay off your own credit card using another customer's money.**
   You should only be able to draw from *your* accounts. Can you make Bob pay
   Alice's credit-card bill?

2. **Read another customer's statement.**
   Your statement is yours alone. Can you pull up Bob's or Carol's full
   transaction history — salary, rent, spending and all?

3. **Get hold of the application's internal logs.**
   The app writes operational logs that were never meant for customers. They
   exist somewhere in the system — find a way to read them, and notice what they
   leak.

4. **Run code on the banking server.** *(Injection — SSTI)*
   The “Open a new account” feature greets you by the **nickname** you choose.
   That greeting is built from a server-side template. What happens if your
   nickname *is* a template expression? Start with `<%= 7*7 %>` and escalate.

5. **Open an account that isn't empty.** *(Mass Assignment)*
   New accounts are supposed to start at $0.00 — the form only lets you set a
   nickname. But the server builds the account from whatever the request body
   contains. Can you make it accept a starting **balance** the form never asked
   for?

For each one, figure out **what the correct check would have been** and where it
is missing.

---

## How to discover the vulnerabilities

This exercise is designed to be solved four different ways. Access-control flaws
behave very differently from injection flaws under tooling — pay attention to
which methods work and which don't.

### 1. Manual testing (in the browser + an intercepting proxy)
The dashboard exposes the flaws — but not all of them are obvious by clicking:
- The **“Pay from account”** control is a **dropdown that only lists accounts you
  own**, so the UI looks safe. The ownership rule is enforced only in the browser.
  Put **Burp Suite** or **OWASP ZAP** in front of the browser, intercept the
  `POST /api/cards/pay`, and rewrite `from_account` to another customer's number
  before it reaches the server. This is the more realistic class of bug: the
  client constrains the input, the server forgets to.
- The **statement account** box is an editable text field — change it. Either way,
  inspect the requests to `/api/accounts/<n>/transactions` in your proxy. Account
  numbers are short and sequential (`5021-0001`, `5021-0002`, …) — trivial to
  enumerate.

### 2. Code review
Open `backend/app/controllers/` and read the controllers. Each intentional flaw
is marked with a `# VULNERABILITY N:` comment explaining what it is and why it is
exploitable. Compare `cards_controller.rb` (vulnerable) with
`transfers_controller.rb` (the correct pattern) — the difference *is* the bug.

### 3. SAST (Brakeman)
```bash
cd backend && bin/brakeman
```
**Brakeman finds the injection and the mass assignment — and is blind to all
three access-control bugs. That split is the lesson.** It reports exactly two
warnings:

| Brakeman finding | Confidence | This exercise |
|------------------|-----------|---------------|
| `Template Injection` — value used directly in `ERB` | High | **Vuln 5 (SSTI)** |
| `Mass Assignment` — `permit!` allows any keys        | Medium | **Vuln 4 (Mass Assignment)** |

Static analysers detect dangerous *sinks* (template eval, `permit!`, SQL strings,
`eval`, file paths). Both bonus bugs have a sink, so Brakeman nails them. But the
three **broken-access-control** flaws (vulns 1–3) have **no sink**: the code is
"safe" line-by-line and only wrong relative to *who should be allowed to run it*.
Brakeman says nothing about them. A clean — or even a non-empty — SAST report
tells you nothing about A01; those bugs are found by humans and by DAST.

> Note: `bin/brakeman` is wired with `--ensure-latest`, so it refuses to run
> unless you are on the newest Brakeman release. If it just prints a version
> notice and exits, run `cd backend && bundle exec brakeman` instead.

### 4. DAST / fuzzing
- **Authorization testing**: with Burp/ZAP, capture a request as Alice, then
  replay it with another account number in the path/body and watch it succeed.
- **Forced browsing / content discovery**: not every endpoint is linked from the
  UI. Fuzz the API surface for hidden paths, e.g.

  ```bash
  ffuf -u http://localhost:3000/api/FUZZ -w /usr/share/seclists/Discovery/Web-Content/common.txt \
       -H "Authorization: Bearer <your-token>" -mc 200,403
  feroxbuster -u http://localhost:3000/api/ -H "Authorization: Bearer <your-token>"
  ```

---

## Project layout

```
owasp-top-10-a01/
├── backend/                 # Rails 8 API-only app (in-memory store, no DB)
│   ├── app/controllers/
│   │   ├── application_controller.rb     # auth helpers (authenticate_user!, require_admin!)
│   │   └── api/
│   │       ├── sessions_controller.rb    # login / logout
│   │       ├── accounts_controller.rb    # /me, statement   ← VULNERABILITY 2
│   │       │                             # open account     ← VULNERABILITIES 4 & 5
│   │       ├── transfers_controller.rb   # money transfer   (secure reference)
│   │       ├── cards_controller.rb       # card payment     ← VULNERABILITY 1
│   │       └── admin/dashboard_controller.rb                ← VULNERABILITY 3
│   └── config/initializers/store.rb      # seed users, transactions, logs
├── frontend/                # Vue 3 + Vite + Tailwind SPA
│   └── src/
│       ├── views/           # LoginView, DashboardView, AdminView
│       ├── services/api.js
│       └── components/HintButton.vue
├── install.sh
└── start.sh
```

---

<details>
<summary><strong>⚠️ Spoilers — full solution & walk-through (open only when you're done)</strong></summary>

### Vulnerability 1 — Pay your card from someone else's account
The UI renders the funding account as a **dropdown that only lists accounts the
signed-in customer owns** (checking + savings), so the bug isn't visible by
clicking. But `POST /api/cards/pay` reads the **funding account from the request
body** (`from_account`) and debits it without checking it belongs to the caller —
the client-side constraint is never re-enforced server-side. Intercept the
request (or just replay it with `curl`) and swap in another customer's number:

```bash
TOKEN=... # Alice's bearer token from the login response
curl -X POST http://localhost:3000/api/cards/pay \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"from_account":"5021-0002","amount":1000}'
```
Alice's card balance drops while **Bob's** balance is debited. *Fix:* force the
funding account server-side to one of `current_user`'s own accounts (reject any
`from_account` not in `current_user[:accounts]`), the same way `transfers#create`
scopes the source to `current_user`.

### Vulnerability 2 — Read anyone's statement (IDOR)
`GET /api/accounts/:account_number/transactions` looks up transactions straight
from the URL with no ownership check.

```bash
curl http://localhost:3000/api/accounts/5021-0002/transactions \
  -H "Authorization: Bearer $TOKEN"
```
*Fix:* reject the request unless `account_number == current_user[:account_number]`
(or the caller is staff).

### Vulnerability 3 — Read the application logs (missing function-level authz)
Here is the part that is **not mentioned anywhere else in this README on
purpose**:

There is a **hidden administrator** and an **operations console**.

- A fourth, privileged user exists — `admin` / `V@ultStr33t-0ps!2024`
  (account `5021-0000`, `role: "admin"`). It is never advertised in the customer
  UI. Real staff use it to monitor activity, **read the application logs**, and
  **block** suspicious customers.
- The console lives at the SPA route **`/admin`** (`frontend/src/views/AdminView.vue`)
  and is backed by **`/api/admin/*`** endpoints. Neither is linked from the
  navigation — but the route is sitting in the client-side bundle
  (`frontend/src/router/index.js`) and the API paths show up under content
  discovery / fuzzing.

**How a participant discovers it**
- *Client-side analysis:* read the JS bundle / Vue router and find the `/admin`
  route and the `adminLogs`/`adminTransactions`/`adminUsers` calls in
  `services/api.js`.
- *Fuzzing:* `ffuf`/`feroxbuster` against `/api/` surfaces `/api/admin/logs`,
  `/api/admin/transactions`, `/api/admin/users`.

**Why it's exploitable**
`Api::Admin::DashboardController` runs `before_action :authenticate_user!` but
**never calls `require_admin!`**. So *any logged-in customer* who reaches the
endpoints gets full access:

```bash
# As Alice — a plain customer — read the raw logs:
curl http://localhost:3000/api/admin/logs -H "Authorization: Bearer $TOKEN"
```
or simply browse to **http://localhost:5173/admin** while logged in as Alice.

The logs leak a password-reset token (`prt_9f3a1c7e8b24`), internal IPs, a backup
location, and an admin API key (`vs_live_4e7b91d0c2a8`). The same broken
authorization lets a customer **block other users** via
`POST /api/admin/users/:id/block`.

*Fix:* add `before_action :require_admin!` to the admin controller (the helper
already exists in `ApplicationController` — it is simply never wired up).

### Vulnerability 4 — Open an account with a smuggled balance (Mass Assignment)
`POST /api/accounts` builds the new account by mass-assigning the **entire request
body** (`params.permit!`). The form only sends `label`, and new accounts are meant
to start at $0.00 — but the server never restricts the accepted keys, so any
attribute you add is copied straight onto the account.

```bash
curl -X POST http://localhost:3000/api/accounts \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"label":"Slush","balance":250000}'
```
The response — and your account dropdown after a refresh — show a brand-new
account pre-loaded with $250,000 that was never deposited. (`number` can be
smuggled the same way.) *Fix:* permit only `:label`
(`params.require(:account).permit(:label)` or an explicit allow-list) and set the
balance and account number on the server.

### Vulnerability 5 — Run code on the server (SSTI → RCE)
The same endpoint builds a welcome banner by interpolating your nickname into an
**ERB template string** and evaluating it server-side
(`ERB.new("…#{label}…").result`). The nickname lands inside the template *before*
ERB compiles it, so ERB tags in the nickname execute.

```bash
# Arithmetic — proves the expression is evaluated:
curl -X POST http://localhost:3000/api/accounts \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"label":"<%= 7*7 %>"}'
#  → "welcome":"Welcome to your new 49 account, …"

# Remote code execution:
curl -X POST http://localhost:3000/api/accounts \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"label":"<%= `id` %>"}'
#  → "welcome":"Welcome to your new uid=1000(…) … account, …"
```
You can also trigger it straight from the dashboard: type `<%= 7*7 %>` into the
**“Open a new account”** nickname field and watch the banner render `49`. *Fix:*
never compile user input as a template — pass the nickname as plain data (ordinary
string interpolation in the JSON response, not ERB).

### The underlying theme
The three access-control bugs are the same mistake in three costumes: **the server
authenticates the user but trusts the client for authorization.** The correct fix
is always to derive identity/authority from the *session* (`current_user`) on the
server, and to check it on *every* sensitive action. The two bonus bugs add a
second theme: **never trust the shape or content of the request body** — allow-list
the fields you accept (vuln 4) and treat user input as data, never as code
(vuln 5).

</details>
