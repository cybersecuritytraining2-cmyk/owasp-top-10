class ApplicationController < ActionController::API
  # Stateless bearer-token auth. The token is handed out by POST /api/login and
  # maps to a user id in Store::SESSIONS. There is no database and no session
  # cookie — every protected request must send `Authorization: Bearer <token>`.

  attr_reader :current_user

  private

  def authenticate_user!
    token = bearer_token
    @current_user = Store.user_by_token(token) if token

    return render json: { error: "Not authenticated" }, status: :unauthorized unless @current_user

    if @current_user[:blocked]
      render json: { error: "This account has been blocked. Contact support." }, status: :forbidden
    end
  end

  # Helper available to controllers that want to enforce staff-only access.
  def require_admin!
    return if @current_user && @current_user[:role] == "admin"

    render json: { error: "Forbidden" }, status: :forbidden
  end

  def bearer_token
    header = request.headers["Authorization"].to_s
    header[/\ABearer (.+)\z/, 1]
  end

  def user_json(user)
    primary = Store.primary_account(user)
    {
      id:             user[:id],
      name:           user[:name],
      username:       user[:username],
      role:           user[:role],
      account_number: primary[:number],
      balance:        primary[:balance].round(2),
      # The customer's own accounts — used to populate the "pay from" dropdown.
      accounts:       user[:accounts].map do |a|
        { number: a[:number], label: a[:label], balance: a[:balance].round(2) }
      end,
      card:           user[:card]
    }
  end
end
