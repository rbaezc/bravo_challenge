defmodule BravoWeb.PageControllerTest do
  use BravoWeb.ConnCase
  import Phoenix.LiveViewTest

  test "GET / redirects to login when not authenticated", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/login"
  end

  test "GET / loads the dashboard LiveView when authenticated", %{conn: conn} do
    conn =
      Plug.Test.init_test_session(conn, %{
        "current_user" => %{username: "admin", role: "admin", name: "Administrador"}
      })

    {:ok, _view, html} = live(conn, ~p"/")
    assert html =~ "Evaluación de Crédito Bravo"
  end
end
