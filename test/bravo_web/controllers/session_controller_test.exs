defmodule BravoWeb.SessionControllerTest do
  use BravoWeb.ConnCase

  import Bravo.AccountsFixtures

  describe "GET /login" do
    test "renders the login form", %{conn: conn} do
      conn = get(conn, ~p"/login")
      html = html_response(conn, 200)
      assert html =~ "Iniciar sesión"
      assert html =~ "Evaluación de Crédito Bravo"
    end
  end

  describe "POST /login" do
    setup do
      %{user: user_fixture(%{username: "alice", password: "supersecret", role: "admin"})}
    end

    test "valid credentials log in and redirect to the dashboard", %{conn: conn} do
      conn = post(conn, ~p"/login", username: "alice", password: "supersecret")
      assert redirected_to(conn) == ~p"/"
      assert get_session(conn, :current_user).role == "admin"
    end

    test "invalid credentials re-render the form with an error", %{conn: conn} do
      conn = post(conn, ~p"/login", username: "alice", password: "wrong")
      html = html_response(conn, 200)
      assert html =~ "inválidos"
      refute get_session(conn, :current_user)
    end
  end

  describe "DELETE /logout" do
    test "clears the session and redirects to login", %{conn: conn} do
      conn =
        conn
        |> Plug.Test.init_test_session(%{
          "current_user" => %{username: "admin", role: "admin", name: "Administrador"}
        })
        |> delete(~p"/logout")

      assert redirected_to(conn) == ~p"/login"
      refute get_session(conn, :current_user)
    end
  end
end
