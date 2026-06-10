defmodule Bravo.Domain.StateMachine do
  @moduledoc """
  Pure state-machine logic. Receives the transition table (loaded from the DB by
  `Bravo.Workflow`) as `%{country_or_nil => %{from => [to, ...]}}`. A country
  override replaces the default transitions for a given from-state.
  """

  @doc "Statuses reachable from `from` for `country` (override on top of default)."
  def allowed_transitions(transitions, country, from) do
    default = Map.get(transitions, nil, %{})
    override = Map.get(transitions, country, %{})

    Map.merge(default, override)
    |> Map.get(from, [])
  end

  @doc "True if `from -> to` is allowed for `country`. A no-op (`from == to`) is valid."
  def can_transition?(_transitions, _country, same, same), do: true

  def can_transition?(transitions, country, from, to) do
    to in allowed_transitions(transitions, country, from)
  end
end
