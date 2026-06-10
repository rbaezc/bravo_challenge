defmodule Bravo.CreditRequest do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "credit_requests" do
    field :country, :string
    field :full_name, :string
    field :identity_document, :string
    field :requested_amount, :decimal
    field :monthly_income, :decimal
    field :request_date, :utc_datetime
    field :status, :string
    field :bank_info, :map

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(credit_request, attrs) do
    credit_request
    |> cast(attrs, [
      :country,
      :full_name,
      :identity_document,
      :requested_amount,
      :monthly_income,
      :request_date,
      :status,
      :bank_info
    ])
    |> validate_required([
      :country,
      :full_name,
      :identity_document,
      :requested_amount,
      :monthly_income,
      :request_date,
      :status
    ])
    |> validate_inclusion(:status, Bravo.Workflow.statuses())
    |> validate_document_format()
    |> validate_status_transition()
  end

  # Enforces the credit request state machine: an existing request can only
  # move to a status reachable from its current one (per country).
  defp validate_status_transition(changeset) do
    new_status = get_field(changeset, :status)
    old_status = changeset.data.status
    country = get_field(changeset, :country)

    cond do
      # No new status or invalid status: handled by other validations.
      is_nil(new_status) ->
        changeset

      # New record (no previous status): any valid status is an acceptable start.
      is_nil(old_status) ->
        changeset

      Bravo.Workflow.can_transition?(country, old_status, new_status) ->
        changeset

      true ->
        add_error(
          changeset,
          :status,
          "invalid transition from '#{old_status}' to '#{new_status}'"
        )
    end
  end

  defp validate_document_format(changeset) do
    country = get_field(changeset, :country)
    document = get_field(changeset, :identity_document)

    if country && document do
      case Bravo.Domain.Rules.validate_document(country, document) do
        :ok -> changeset
        {:error, message} -> add_error(changeset, :identity_document, message)
      end
    else
      changeset
    end
  end
end
