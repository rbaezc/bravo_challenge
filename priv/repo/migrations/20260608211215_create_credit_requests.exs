defmodule Bravo.Repo.Migrations.CreateCreditRequests do
  use Ecto.Migration

  def change do
    create table(:credit_requests, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :country, :string
      add :full_name, :string
      add :identity_document, :string
      add :requested_amount, :decimal
      add :monthly_income, :decimal
      add :request_date, :utc_datetime
      add :status, :string
      add :bank_info, :map

      timestamps(type: :utc_datetime)
    end
  end
end
