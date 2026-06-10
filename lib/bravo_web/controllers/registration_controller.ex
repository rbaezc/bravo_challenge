defmodule BravoWeb.RegistrationController do
  use BravoWeb, :controller

  alias Bravo.Accounts
  alias Bravo.Accounts.User
  alias BravoWeb.Auth.Session

  def new(conn, _params) do
    if get_session(conn, :current_user) do
      redirect(conn, to: ~p"/")
    else
      changeset = Accounts.change_user_registration(%User{})
      render(conn, :new, changeset: changeset, page_title: "Crear cuenta")
    end
  end

  def create(conn, %{"user" => user_params}) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        conn
        |> Session.log_in_user(user)
        |> put_flash(:info, "Cuenta creada. ¡Bienvenido, #{user.name}!")
        |> redirect(to: ~p"/")

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_flash(:error, "Revisa los errores del formulario.")
        |> render(:new, changeset: changeset, page_title: "Crear cuenta")
    end
  end
end
