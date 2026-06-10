defmodule Bravo.Workflow do
  @moduledoc """
  Data-driven workflow: reads states and transitions from the `credit_statuses`
  and `credit_status_transitions` tables, so new states/flows can be added at
  runtime without a deploy. Pure transition logic lives in `Domain.StateMachine`.

  The loaded workflow is cached (Cachex) and invalidated on mutation. The cache
  can be disabled with `config :bravo, :workflow_cache, false` (used in tests).
  """
  import Ecto.Query

  alias Bravo.Repo
  alias Bravo.Domain.StateMachine
  alias Bravo.Workflow.{Status, Transition}

  @cache :workflow_cache
  @cache_key :workflow

  # --- Read API (mirrors the previous StateMachine public API) ---

  @doc "All status keys, ordered by position."
  def statuses, do: Enum.map(load().statuses, & &1.key)

  @doc "Full status structs, ordered by position (for UI: label, color, ...)."
  def status_list, do: load().statuses

  @doc "Map of status key => status struct."
  def status_map, do: Map.new(load().statuses, &{&1.key, &1})

  @doc "Status keys flagged as valid initial states."
  def initial_statuses do
    load().statuses |> Enum.filter(& &1.is_initial) |> Enum.map(& &1.key)
  end

  @doc "True if `key` is a known status."
  def valid_status?(key), do: Enum.any?(load().statuses, &(&1.key == key))

  @doc "Statuses reachable from `from` for `country`."
  def allowed_transitions(country, from) do
    StateMachine.allowed_transitions(load().transitions, country, from)
  end

  @doc "True if `from -> to` is allowed for `country`."
  def can_transition?(country, from, to) do
    StateMachine.can_transition?(load().transitions, country, from, to)
  end

  @doc "Allowed transitions flagged `manual` (UI actions) from `(country, from)`."
  def manual_transitions(country, from) do
    allowed = allowed_transitions(country, from)
    manual = load().manual

    for to <- allowed,
        row = find_manual(manual, country, from, to),
        do: %{to: to, label: row.action_label || to}
  end

  defp find_manual(manual, country, from, to) do
    Enum.find(manual, fn t ->
      t.from_status == from and t.to_status == to and t.country in [country, nil]
    end)
  end

  # --- Write API (runtime extension; also used by tests) ---

  @doc "Adds (or updates) a status, then invalidates the cache."
  def upsert_status(attrs) do
    key = attrs[:key] || attrs["key"]

    (Repo.get_by(Status, key: key) || %Status{})
    |> Status.changeset(attrs)
    |> Repo.insert_or_update()
    |> tap_invalidate()
  end

  @doc "Adds an allowed transition, then invalidates the cache."
  def add_transition(attrs) do
    %Transition{}
    |> Transition.changeset(attrs)
    |> Repo.insert()
    |> tap_invalidate()
  end

  @doc "Clears the workflow cache (call after mutating statuses/transitions)."
  def invalidate do
    if cache_enabled?(), do: Cachex.del(@cache, @cache_key)
    :ok
  end

  defp tap_invalidate(result) do
    invalidate()
    result
  end

  # --- Loading / caching ---

  defp load do
    if cache_enabled?() do
      case Cachex.get(@cache, @cache_key) do
        {:ok, nil} ->
          workflow = build()
          Cachex.put(@cache, @cache_key, workflow)
          workflow

        {:ok, workflow} ->
          workflow
      end
    else
      build()
    end
  end

  defp build do
    statuses = Repo.all(from s in Status, order_by: [asc: s.position, asc: s.key])
    transitions = Repo.all(Transition)

    by_country =
      transitions
      |> Enum.group_by(& &1.country)
      |> Map.new(fn {country, rows} ->
        {country, Enum.group_by(rows, & &1.from_status, & &1.to_status)}
      end)

    %{
      statuses: statuses,
      transitions: by_country,
      manual: Enum.filter(transitions, & &1.manual)
    }
  end

  defp cache_enabled?, do: Application.get_env(:bravo, :workflow_cache, true)
end
