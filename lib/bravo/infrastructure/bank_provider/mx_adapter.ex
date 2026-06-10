defmodule Bravo.Infrastructure.BankProvider.MXAdapter do
  @moduledoc """
  Adapter for fetching banking information in Mexico (MX).
  """
  @behaviour Bravo.Application.Ports.BankProvider

  @impl true
  def fetch_customer_info(document) do
    # Simulates fetching information from a Mexican banking provider (e.g. Círculo de Crédito or Banxico)
    # Basic CURP regex check (18 alphanumeric characters)
    if String.match?(document, ~r/^[A-Z]{4}[0-9]{6}[HM][A-Z]{5}[A-Z0-9][0-9]$/i) do
      {:ok,
       %{
         provider: "Círculo de Crédito MX",
         bank_name: "BBVA México",
         account_clabe: "012180001509230192",
         credit_score: 710,
         active_debts_mxn: Decimal.new("8000.00"),
         validation_status: "verified"
       }}
    else
      {:error, :invalid_document_format}
    end
  end
end
