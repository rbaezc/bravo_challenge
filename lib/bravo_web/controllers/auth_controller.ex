defmodule BravoWeb.AuthController do
  use BravoWeb, :controller

  alias BravoWeb.Auth.Token

  @doc """
  Generates a JWT token for the given user_id and role.
  Accepts a JSON payload like:
  {
    "user_id": "123",
    "role": "admin"
  }
  """
  def token(conn, params) do
    user_id = Map.get(params, "user_id", "demo_user")
    role = Map.get(params, "role", "user")

    case Token.generate_token(user_id, role) do
      {:ok, token} ->
        json(conn, %{
          token: token,
          token_type: "Bearer",
          expires_in: 7200,
          role: role,
          user_id: user_id
        })

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Failed to generate token: #{inspect(reason)}"})
    end
  end
end
