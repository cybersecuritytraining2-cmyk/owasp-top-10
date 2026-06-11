module Api
  class AccountsController < ApplicationController
    before_action :authenticate_user!

    # GET /api/me — the signed-in customer's own profile, balance and card.
    def me
      render json: user_json(current_user)
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
