defmodule BravoWeb.SessionController do
  use BravoWeb, :controller

  alias Bravo.Accounts
  alias Bravo.Accounts.User
  alias BravoWeb.Auth.Session

  def new(conn, _params) do
    # Already logged in? Go straight to the dashboard.
    if get_session(conn, :current_user) do
      redirect(conn, to: ~p"/")
    else
      render(conn, :new, error: nil, page_title: "Iniciar sesión")
    end
  end

  def create(conn, %{"username" => username, "password" => password}) do
    case Accounts.get_user_by_username_and_password(username, password) do
      %User{} = user ->
        conn
        |> Session.log_in_user(user)
        |> put_flash(:info, "Bienvenido, #{user.name}")
        |> redirect(to: ~p"/")

      _ ->
        conn
        |> put_flash(:error, "Usuario o contraseña inválidos.")
        |> render(:new, error: "Usuario o contraseña inválidos.", page_title: "Iniciar sesión")
    end
  end

  def delete(conn, _params) do
    conn
    |> Session.log_out_user()
    |> put_flash(:info, "Sesión cerrada.")
    |> redirect(to: ~p"/login")
  end
end
