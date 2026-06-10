defmodule Bravo.Infrastructure.BankProvider.Factory do
  @moduledoc """
  Factory to get the correct BankProvider adapter depending on the country.
  """
  alias Bravo.Infrastructure.BankProvider.COAdapter
  alias Bravo.Infrastructure.BankProvider.ESAdapter
  alias Bravo.Infrastructure.BankProvider.MXAdapter

  def get_adapter(country) do
    # During testing, we can inject a mock if configured, otherwise default to country adapters
    case Application.get_env(:bravo, :bank_provider_mock) do
      nil ->
        case String.upcase(country) do
          "ES" -> {:ok, ESAdapter}
          "MX" -> {:ok, MXAdapter}
          "CO" -> {:ok, COAdapter}
          other -> {:error, "Unsupported country bank provider: #{other}"}
        end

      mock_module ->
        {:ok, mock_module}
    end
  end
end
