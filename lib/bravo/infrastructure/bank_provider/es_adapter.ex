defmodule Bravo.Infrastructure.BankProvider.ESAdapter do
  @moduledoc """
  Adapter for fetching banking information in Spain (ES).
  """
  @behaviour Bravo.Application.Ports.BankProvider

  @impl true
  def fetch_customer_info(document) do
    # Simulates fetching information from a Spanish banking provider (e.g. Iberpay or Bank of Spain)
    if String.match?(document, ~r/^[0-9]{8}[TRWAGMYFPDXBNJZSQVHLCKE]$/i) do
      {:ok,
       %{
         provider: "Iberpay ES",
         bank_name: "Banco Santander",
         account_iban: "ES9121000418451234567890",
         credit_rating: "A+",
         active_debts_eur: Decimal.new("1500.00"),
         validation_status: "verified"
       }}
    else
      {:error, :invalid_document_format}
    end
  end
end
