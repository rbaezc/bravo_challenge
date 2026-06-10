defmodule BravoWeb.RegistrationControllerTest do
  use BravoWeb.ConnCase

  import Bravo.AccountsFixtures

  alias Bravo.Accounts

  describe "GET /register" do
    test "renders the registration form", %{conn: conn} do
      conn = get(conn, ~p"/register")
      assert html_response(conn, 200) =~ "Crear cuenta"
    end
  end

  describe "POST /register" do
    test "creates a user, logs in, and redirects to the dashboard", %{conn: conn} do
      conn =
        post(conn, ~p"/register", %{
          "user" => %{
            "username" => "newbie",
            "name" => "New Bie",
            "password" => "supersecret",
            "password_confirmation" => "supersecret"
          }
        })

      assert redirected_to(conn) == ~p"/"
      assert get_session(conn, :current_user).username == "newbie"

      # Self-registration always yields the least-privileged role.
      assert Accounts.get_user_by_username("newbie").role == "user"
    end

    test "re-renders with errors on invalid data", %{conn: conn} do
      conn =
        post(conn, ~p"/register", %{
          "user" => %{
            "username" => "x",
            "name" => "",
            "password" => "short",
            "password_confirmation" => "nope"
          }
        })

      assert html_response(conn, 200) =~ "Crear cuenta"
      refute get_session(conn, :current_user)
    end

    test "rejects a duplicate username", %{conn: conn} do
      _ = user_fixture(%{username: "taken"})

      conn =
        post(conn, ~p"/register", %{
          "user" => %{
            "username" => "taken",
            "name" => "Someone",
            "password" => "supersecret",
            "password_confirmation" => "supersecret"
          }
        })

      assert html_response(conn, 200) =~ "Crear cuenta"
      refute get_session(conn, :current_user)
    end
  end
end
