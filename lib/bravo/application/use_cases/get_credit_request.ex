defmodule Bravo.Application.UseCases.GetCreditRequest do
  @moduledoc """
  Use case to get a single credit_request.
  """

  def execute(repo, id) do
    :telemetry.span(
      [:bravo, :use_case, :get_credit_request],
      %{id: id},
      fn ->
        result = repo.get_credit_request(id)
        {result, %{}}
      end
    )
  end
end
