defmodule BravoWeb.MetricsController do
  @moduledoc """
  Exposes metrics in Prometheus text format at `GET /metrics`. Left unauthenticated
  for evaluation; in a real cluster it would be protected (network policy / auth).
  """
  use BravoWeb, :controller

  def index(conn, _params) do
    metrics = TelemetryMetricsPrometheus.Core.scrape()

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, metrics)
  end
end
