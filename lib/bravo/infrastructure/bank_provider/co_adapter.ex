defmodule Bravo.Infrastructure.BankProvider.COAdapter do
  @moduledoc """
  Colombia (CO) bank provider adapter. Returns a `total_debt` figure used by the
  Colombian debt-to-income rule, which ES/MX providers don't expose.
  """
  @behaviour Bravo.Application.Ports.BankProvider

  @impl true
  def fetch_customer_info(document) do
    # Simulates a Colombian credit bureau (e.g. DataCrédito / TransUnion CO)
    if String.match?(document, ~r/^[0-9]{6,10}$/) do
      {:ok,
       %{
         provider: "DataCrédito CO",
         bank_name: "Bancolombia",
         account_number: "CO29000123456789",
         total_debt: Decimal.new("9000000.00"),
         credit_score: 690,
         validation_status: "verified"
       }}
    else
      {:error, :invalid_document_format}
    end
  end
end
