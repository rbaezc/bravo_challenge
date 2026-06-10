defmodule Bravo.Workflow.Transition do
  @moduledoc "An allowed transition between two statuses (optionally per country)."
  use Ecto.Schema
  import Ecto.Changeset

  schema "credit_status_transitions" do
    field :from_status, :string
    field :to_status, :string
    field :country, :string
    field :manual, :boolean, default: false
    field :action_label, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(transition, attrs) do
    transition
    |> cast(attrs, [:from_status, :to_status, :country, :manual, :action_label])
    |> validate_required([:from_status, :to_status])
    |> unique_constraint([:from_status, :to_status, :country],
      name: :credit_status_transitions_unique
    )
  end
end
