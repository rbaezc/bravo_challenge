defmodule Bravo.Application.Ports.BankProvider do
  @moduledoc """
  Port interface for fetching bank information for credit evaluations.
  """

  @callback fetch_customer_info(document :: String.t()) :: {:ok, map()} | {:error, term()}
end
