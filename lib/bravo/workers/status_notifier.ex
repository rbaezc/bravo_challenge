defmodule Bravo.Workers.StatusNotifier do
  @moduledoc """
  Oban worker (queue `:notifications`) that sends the outbound webhook on a status
  change. Enqueued by a PostgreSQL trigger, so automatic and manual transitions
  are notified alike. Runs independently of the `:default` risk-evaluation queue.
  """
  use Oban.Worker, queue: :notifications, max_attempts: 3

  require Logger

  alias Bravo.CreditRequests

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"request_id" => request_id, "new_status" => new_status} = args}) do
    old_status = Map.get(args, "old_status")
    request = CreditRequests.get_credit_request!(request_id)

    Logger.info(
      "StatusNotifier: notifying external systems for #{request_id} " <>
        "(#{old_status || "none"} -> #{new_status})"
    )

    webhook_url = Application.get_env(:bravo, :webhook_url) || "https://httpbin.org/post"

    payload = %{
      event: "credit_request.status_changed",
      request_id: request_id,
      country: request.country,
      old_status: old_status,
      new_status: new_status,
      requested_amount: Decimal.to_string(request.requested_amount),
      notified_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    case Req.post(webhook_url, json: payload, retry: false) do
      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        Logger.info("StatusNotifier: delivered for #{request_id} (status: #{status})")
        emit_metric("ok")
        :ok

      {:ok, %Req.Response{status: status}} ->
        Logger.warning("StatusNotifier: non-2xx for #{request_id} (status: #{status})")
        emit_metric("non_2xx")
        :ok

      {:error, reason} ->
        # Returning an error lets Oban retry (with backoff) up to max_attempts.
        Logger.error("StatusNotifier: delivery failed for #{request_id}: #{inspect(reason)}")
        emit_metric("error")
        {:error, reason}
    end
  end

  # Emits a telemetry event consumed by the Prometheus reporter (see
  # BravoWeb.Telemetry): bravo.webhook.sent.count tagged by :result.
  defp emit_metric(result) do
    :telemetry.execute([:bravo, :webhook, :sent], %{count: 1}, %{result: result})
  end
end
