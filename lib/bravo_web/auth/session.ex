defmodule BravoWeb.Auth.Session do
  @moduledoc """
  Browser session login/logout helpers.

  Stores a minimal, non-sensitive snapshot of the user in the (signed) session
  cookie. The session is renewed on every login/logout to mitigate fixation.
  """
  import Plug.Conn

  alias Bravo.Accounts.User

  @doc "Logs the user in by renewing the session and storing their identity."
  def log_in_user(conn, %User{} = user) do
    conn
    |> renew_session()
    |> put_session(:current_user, %{
      id: user.id,
      username: user.username,
      role: user.role,
      name: user.name
    })
  end

  @doc "Logs the user out by clearing/renewing the session."
  def log_out_user(conn) do
    renew_session(conn)
  end

  defp renew_session(conn) do
    conn
    |> configure_session(renew: true)
    |> clear_session()
  end
end
