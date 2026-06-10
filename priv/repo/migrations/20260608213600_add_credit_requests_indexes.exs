defmodule Bravo.Repo.Migrations.AddCreditRequestsIndexes do
  use Ecto.Migration

  @moduledoc """
  Indexes supporting the most frequent access patterns documented in the README:
    * combined filtering by country + status (dashboard / API listing)
    * chronological listing and date-range queries
    * fast lookups by identity document (provider integration / fraud checks)
  """

  def change do
    create index(:credit_requests, [:country, :status], name: :idx_requests_country_status)
    create index(:credit_requests, [:request_date], name: :idx_requests_date)
    create index(:credit_requests, [:identity_document], name: :idx_requests_identity_doc)
  end
end
