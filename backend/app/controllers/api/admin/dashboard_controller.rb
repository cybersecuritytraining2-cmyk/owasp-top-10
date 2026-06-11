module Api
  module Admin
    # Operations console used by Vault Street staff to monitor activity, read the
    # application logs, and block suspicious customers. It lives under /api/admin
    # and the matching screen is at /admin in the SPA. Neither is linked from the
    # customer UI, but the route is present in the client-side bundle.
    class DashboardController < ApplicationController
      # The endpoints require a valid login…
      before_action :authenticate_user!

      # VULNERABILITY 3 (Broken Access Control / Missing Function-Level
      # Authorization): these are staff-only operations, but the controller only
      # checks that the caller is *authenticated*, not that they are an *admin*.
      # The `require_admin!` filter exists in ApplicationController and is exactly
      # what should guard this controller — but it is never invoked here. As a
      # result any logged-in customer who discovers the admin routes (by reading
      # the JS bundle or fuzzing /api/admin/*) can read the full application logs
      # — which leak password-reset tokens, internal IPs and an API key — list
      # every customer's transactions, and block/unblock accounts.
      #
      #   before_action :require_admin!   # <-- the missing line

      # GET /api/admin/logs — full application log.
      def logs
        render json: { logs: Store::LOGS }
      end

      # GET /api/admin/transactions — every ledger entry across all accounts.
      def transactions
        render json: { transactions: Store::TRANSACTIONS.sort_by { |t| t[:created_at] }.reverse }
      end

      # GET /api/admin/users — customer directory with balances.
      def users
        render json: {
          users: Store::USERS.values.map do |u|
            primary = Store.primary_account(u)
            {
              id:             u[:id],
              name:           u[:name],
              username:       u[:username],
              role:           u[:role],
              account_number: primary[:number],
              balance:        primary[:balance].round(2),
              blocked:        u[:blocked]
            }
          end
        }
      end

      # POST /api/admin/users/:id/block
      def block
        set_blocked(true)
      end

      # POST /api/admin/users/:id/unblock
      def unblock
        set_blocked(false)
      end

      private

      def set_blocked(value)
        user = Store::USERS[params[:id].to_i]
        return render json: { error: "User not found" }, status: :not_found unless user

        user[:blocked] = value
        Store.log("INFO  ops  — user=#{user[:username]} blocked=#{value} by=#{current_user[:username]}")
        render json: { id: user[:id], blocked: user[:blocked] }
      end
    end
  end
end
