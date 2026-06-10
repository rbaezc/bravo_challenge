defmodule BravoWeb.MetricsControllerTest do
  use BravoWeb.ConnCase

  test "GET /metrics returns Prometheus text", %{conn: conn} do
    conn = get(conn, ~p"/metrics")

    assert response(conn, 200)
    assert response_content_type(conn, :text) =~ "text/plain"
  end
end
