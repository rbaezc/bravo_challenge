defmodule Bravo.Application.Ports.CreditRequestRepository do
  @moduledoc """
  Port defining the interface for CreditRequest persistence.
  """
  alias Bravo.Domain.Entities.CreditRequest

  @callback get_credit_request(id :: term()) :: {:ok, CreditRequest.t()} | {:error, :not_found}
  @callback list_credit_requests(filters :: map()) :: [CreditRequest.t()]
  @callback count_credit_requests(filters :: map()) :: non_neg_integer()
  @callback save_credit_request(params :: map()) :: {:ok, CreditRequest.t()} | {:error, term()}
  @callback delete_credit_request(id :: term()) :: :ok | {:error, term()}
  @callback list_status_history(id :: term()) :: [map()]
end
