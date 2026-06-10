defmodule Bravo.Infrastructure.Events.Listener do
  @moduledoc """
  GenServer that listens to native PostgreSQL NOTIFY events on the
  'credit_request_status_changes' channel and broadcasts them to Phoenix PubSub.
  """
  use GenServer
  require Logger

  alias Bravo.Repo

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Fetch DB configuration to connect to the same PostgreSQL instance
    db_config = Repo.config()

    case Postgrex.Notifications.start_link(db_config) do
      {:ok, pid} ->
        {:ok, ref} = Postgrex.Notifications.listen(pid, "credit_request_status_changes")

        Logger.info(
          "Successfully subscribed to native Postgres channel: credit_request_status_changes"
        )

        {:ok, %{notifications_pid: pid, listen_ref: ref}}

      {:error, reason} ->
        Logger.error("Failed to start Postgrex.Notifications listener: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_info({:notification, _pid, _ref, "credit_request_status_changes", payload}, state) do
    Logger.info("Received native PG notification: #{payload}")

    case Jason.decode(payload) do
      {:ok, %{"id" => id, "old_status" => old_status, "new_status" => new_status}} ->
        # Broadcast to Phoenix PubSub so the LiveView UI updates instantly
        Phoenix.PubSub.broadcast(
          Bravo.PubSub,
          "credit_requests",
          {:credit_request_status_changed,
           %{id: id, old_status: old_status, new_status: new_status}}
        )

      _ ->
        Logger.error("Failed to parse PG notification payload: #{inspect(payload)}")
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("Received unexpected message in PG listener: #{inspect(msg)}")
    {:noreply, state}
  end
end
