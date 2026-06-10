defmodule BravoWeb.Auth.Plug do
  @moduledoc """
  Plug to authenticate API requests using JWT.
  """
  import Plug.Conn
  alias BravoWeb.Auth.Token

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        case Token.verify_token(token) do
          {:ok, %{"user_id" => user_id, "role" => role}} ->
            conn
            |> assign(:current_user_id, user_id)
            |> assign(:current_role, role)

          _ ->
            unauthorized(conn)
        end

      _ ->
        unauthorized(conn)
    end
  end

  defp unauthorized(conn) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(401, Jason.encode!(%{error: "Unauthorized. JWT is missing or invalid."}))
    |> halt()
  end
end
