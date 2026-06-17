require "erb"

module Api
  class AccountsController < ApplicationController
    before_action :authenticate_user!

    # GET /api/me — the signed-in customer's own profile, balance and card.
    def me
      render json: user_json(current_user)
    end

    # POST /api/accounts — open a new account for the signed-in customer.
    # Body: { "label": "Vacation Fund" }
    #
    # The "Open a new account" form only collects a label/nickname. Newly opened
    # accounts are supposed to start at a $0.00 balance and get a fresh, server-
    # assigned account number.
    def create
      # VULNERABILITY 4 (Mass Assignment): the new account is built straight from
      # the request body via `params.permit!` — every key the client sends is
      # copied onto the account hash. The UI only submits `label`, but nothing on
      # the server restricts which attributes are accepted, so an attacker can
      # smuggle in extra fields the form never exposes. Posting
      #   { "label": "Savings", "balance": 250000 }
      # opens an account pre-loaded with a quarter-million dollars of money that
      # was never deposited; adding "number" lets them choose (or collide with)
      # an account number. The fix is to permit only :label and to force the
      # balance and number server-side.
      attrs = params.permit!.to_h.symbolize_keys
                    .except(:controller, :action, :format, :account)

      account = {
        number:  Store.next_account_number,
        label:   "New Account",
        balance: 0.0
      }.merge(attrs)
      account[:balance] = account[:balance].to_f
      account[:label]   = account[:label].to_s

      current_user[:accounts] << account
      Store.log("INFO  acct — opened account=#{account[:number]} " \
                "label=#{account[:label]} balance=#{format('%.2f', account[:balance])} " \
                "user=#{current_user[:username]}")

      # VULNERABILITY 5 (Server-Side Template Injection): the customer-supplied
      # label is interpolated into an ERB template string that is then evaluated
      # on the server to produce a personalized welcome banner. Because the label
      # lands inside the template *before* ERB compiles it, any ERB tags the
      # customer types are executed server-side: a label of "<%= 7*7 %>" renders
      # as "49", and "<%= `id` %>" or "<%= system('…') %>" runs arbitrary shell
      # commands as the Rails process — full remote code execution. User input
      # must never be compiled as a template; it should be passed as plain data
      # (e.g. ordinary string interpolation in the JSON response, not ERB).
      welcome = ERB.new(
        "Welcome to your new #{account[:label]} account, #{current_user[:name]}!"
      ).result(binding)

      render json: {
        account: {
          number:  account[:number],
          label:   account[:label],
          balance: account[:balance].round(2)
        },
        welcome: welcome
      }, status: :created
    end

    # GET /api/accounts/:account_number/transactions
    # Returns the statement (transaction history) for an account.
    #
    # VULNERABILITY 2 (Broken Access Control / IDOR): the account number comes
    # straight from the URL and is used to look up transactions without ever
    # checking that it belongs to `current_user`. Any authenticated customer can
    # read anyone else's statement by changing the account number — e.g. a user
    # signed in as 5021-0001 can request /api/accounts/5021-0002/transactions
    # and see Bob's salary, rent, and spending. Account numbers are short and
    # sequential, so they are trivial to enumerate.
    def transactions
      account_number = params[:account_number]
      found = Store.locate_account(account_number)
      return render json: { error: "Account not found" }, status: :not_found unless found

      render json: {
        account_number: account_number,
        holder:         found[:user][:name],
        transactions:   Store.transactions_for(account_number)
      }
    end
  end
end
