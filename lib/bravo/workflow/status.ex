defmodule Bravo.Workflow.Status do
  @moduledoc "A credit request status (data-driven state)."
  use Ecto.Schema
  import Ecto.Changeset

  schema "credit_statuses" do
    field :key, :string
    field :label, :string
    field :color, :string, default: "slate"
    field :is_initial, :boolean, default: false
    field :is_terminal, :boolean, default: false
    field :position, :integer, default: 0

    timestamps(type: :utc_datetime)
  end

  def changeset(status, attrs) do
    status
    |> cast(attrs, [:key, :label, :color, :is_initial, :is_terminal, :position])
    |> validate_required([:key, :label])
    |> update_change(:key, &String.downcase/1)
    |> unique_constraint(:key)
  end
end
