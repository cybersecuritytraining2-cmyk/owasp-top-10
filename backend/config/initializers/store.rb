module Store
  # ── In-memory data store ─────────────────────────────────────────────────────
  # No database. Everything lives in module-level hashes/arrays and resets when
  # the server restarts. This keeps the exercise focused on access-control logic
  # rather than persistence plumbing.

  USERS        = {}   # id => user hash
  SESSIONS     = {}   # bearer token => user id
  TRANSACTIONS = []   # flat list of ledger entries (one per account movement)
  LOGS         = []   # application log lines (login events, admin actions, …)

  USER_COUNTER    = [0]
  TXN_COUNTER     = [0]
  ACCOUNT_COUNTER = [1000]   # customer-opened accounts get numbers from 5021-1001 up

  def self.next_user_id = USER_COUNTER[0] += 1
  def self.next_txn_id  = TXN_COUNTER[0]  += 1

  def self.next_account_number
    ACCOUNT_COUNTER[0] += 1
    format("5021-%04d", ACCOUNT_COUNTER[0])
  end

  # ── Lookups ──────────────────────────────────────────────────────────────────
  def self.user_by_token(token)
    USERS[SESSIONS[token]]
  end

  # Every customer owns one or more accounts (checking + savings). The first
  # account in the list is treated as the primary/checking account.
  def self.primary_account(user)
    user[:accounts].first
  end

  # Find the account hash with the given number across *all* customers, plus the
  # user that owns it. Returns { user:, account: } or nil. Note that this does
  # NOT scope the search to any particular customer — callers that care about
  # ownership must check it themselves.
  def self.locate_account(number)
    USERS.values.each do |u|
      account = u[:accounts].find { |a| a[:number] == number }
      return { user: u, account: account } if account
    end
    nil
  end

  def self.transactions_for(account_number)
    TRANSACTIONS.select { |t| t[:account_number] == account_number }
                .sort_by { |t| t[:created_at] }
                .reverse
  end

  def self.record_txn(account_number, description, amount, balance_after)
    id = next_txn_id
    TRANSACTIONS << {
      id:             id,
      account_number: account_number,
      description:    description,
      amount:         amount,           # positive = credit, negative = debit
      balance_after:  balance_after.round(2),
      created_at:     Time.now.iso8601
    }
    id
  end

  def self.log(line)
    LOGS << "#{Time.now.iso8601}  #{line}"
  end

  # ── Seed data ────────────────────────────────────────────────────────────────
  def self.seed!
    return unless USERS.empty?

    [
      {
        username: "alice", password: "Spring2024!", name: "Alice Johnson",
        role: "customer",
        accounts: [
          { number: "5021-0001", label: "Checking", balance: 8_420.55 },
          { number: "5021-0011", label: "Savings",  balance: 12_300.00 }
        ],
        card: { number: "4716 88•• •••• 2098", limit: 5_000.00, owed: 1_240.30 }
      },
      {
        username: "bob", password: "Hunter2024#", name: "Bob Martinez",
        role: "customer",
        accounts: [
          { number: "5021-0002", label: "Checking", balance: 15_980.10 },
          { number: "5021-0012", label: "Savings",  balance: 40_000.00 }
        ],
        card: { number: "5500 41•• •••• 7733", limit: 12_000.00, owed: 4_512.00 }
      },
      {
        username: "carol", password: "Autumn2024$", name: "Carol Nguyen",
        role: "customer",
        accounts: [
          { number: "5021-0003", label: "Checking", balance: 2_310.75 },
          { number: "5021-0013", label: "Savings",  balance: 5_500.00 }
        ],
        card: { number: "3782 82•• •••• 1006", limit: 3_000.00, owed: 980.55 }
      },
      # Hidden privileged account. Not advertised anywhere in the customer UI.
      # The admin console it unlocks is reachable from the client-side router
      # and from the /api/admin/* endpoints.
      {
        username: "admin", password: "V@ultStr33t-0ps!2024", name: "Vault Street Operations",
        role: "admin",
        accounts: [
          { number: "5021-0000", label: "Operations", balance: 0.00 }
        ],
        card: nil
      }
    ].each do |u|
      id = next_user_id
      USERS[id] = u.merge(id: id, blocked: false)
    end

    seed_transactions!
    seed_logs!
  end

  def self.seed_transactions!
    # A plausible recent history for each customer account. Amounts are signed:
    # positive credits the account, negative debits it. balance_after is seed
    # cosmetics — it does not have to reconcile to the current live balance.
    histories = {
      "5021-0001" => [
        ["Payroll — Northwind Labs",         4_200.00, 8_420.55],
        ["Whole Foods Market",                 -86.42, 4_220.55],
        ["Transfer to 5021-0003 (Carol)",     -150.00, 4_306.97],
        ["Spotify Premium",                     -10.99, 4_456.97],
        ["ATM withdrawal — 5th & Main",       -200.00, 4_467.96],
        ["Credit card payment",               -500.00, 4_667.96]
      ],
      "5021-0011" => [
        ["Opening deposit",                  10_000.00, 10_000.00],
        ["Monthly auto-save",                   300.00, 10_300.00],
        ["Interest payment",                     45.20, 12_300.00]
      ],
      "5021-0002" => [
        ["Payroll — Globex Corporation",     6_500.00, 15_980.10],
        ["Apple Store — MacBook Pro",       -2_499.00,  9_480.10],
        ["Rent — Mercer Property Mgmt",     -2_100.00, 11_979.10],
        ["Transfer from 5021-0001 (Alice)",    250.00, 14_079.10],
        ["Shell Gas Station",                  -71.20, 13_829.10],
        ["Credit card payment",             -1_000.00, 13_900.30]
      ],
      "5021-0012" => [
        ["Opening deposit",                  35_000.00, 35_000.00],
        ["Bonus — Globex Corporation",        5_000.00, 40_000.00]
      ],
      "5021-0003" => [
        ["Payroll — Initech",                3_100.00, 2_310.75],
        ["Transfer from 5021-0001 (Alice)",    150.00, 2_460.75],
        ["Target",                            -142.18, 2_310.75],
        ["Electric — PG&E",                   -118.40, 2_452.93],
        ["Netflix",                            -22.99, 2_571.33],
        ["Credit card payment",               -300.00, 2_594.32]
      ],
      "5021-0013" => [
        ["Opening deposit",                   5_000.00, 5_000.00],
        ["Monthly auto-save",                   500.00, 5_500.00]
      ]
    }

    histories.each do |account_number, rows|
      rows.reverse_each do |desc, amount, bal|
        record_txn(account_number, desc, amount, bal)
      end
    end
  end

  def self.seed_logs!
    log("INFO  boot — Vault Street online banking API started (env=development)")
    log("INFO  auth — login success user=alice ip=10.42.0.17")
    log("INFO  auth — login success user=bob ip=10.42.0.31")
    log("WARN  auth — login failed user=carol ip=203.0.113.92 reason=bad_password attempts=3")
    log("INFO  txn  — transfer 5021-0001 -> 5021-0003 amount=150.00 status=ok")
    log("INFO  card — payment account=5021-0002 card=••7733 amount=1000.00 status=ok")
    # Sensitive operational details a customer should never see — the reason the
    # logs endpoint must be restricted to administrators.
    log("INFO  auth — login success user=admin ip=10.42.0.2 console=/admin")
    log("WARN  ops  — password reset issued user=bob token=prt_9f3a1c7e8b24 expires=15m")
    log("INFO  ops  — nightly backup uploaded s3://vaultstreet-backups/db-2024.sql.gz")
    log("DEBUG cfg  — internal admin api key ADMIN_API_KEY=vs_live_4e7b91d0c2a8 (rotate before prod)")
  end

  # Statement exports are written to disk (tmp/exports). The in-memory data above
  # resets on restart on its own, but files on disk would survive — so wipe any
  # leftover exports at boot to keep a restart a truly clean slate.
  def self.clear_exports!
    dir = Rails.root.join("tmp", "exports")
    FileUtils.rm_f(Dir.glob(dir.join("*.csv"))) if Dir.exist?(dir)
  end
end

require "fileutils"
Store.clear_exports!
Store.seed!
