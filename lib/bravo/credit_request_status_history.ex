defmodule Bravo.CreditRequestStatusHistory do
  @moduledoc """
  Immutable audit record of a credit request status transition.

  Rows are written exclusively by PostgreSQL triggers (see the
  `add_status_history` migration), never from application code.
  """
  use Ecto.Schema

  @foreign_key_type :binary_id
  schema "credit_request_status_history" do
    field :old_status, :string
    field :new_status, :string
    field :credit_request_id, :binary_id

    timestamps(updated_at: false, type: :utc_datetime)
  end
end
