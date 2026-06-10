defmodule Bravo.Application.UseCases.CreateCreditRequest do
  @moduledoc """
  Use case to create a credit_request.
  """

  def execute(repo, params) do
    :telemetry.span(
      [:bravo, :use_case, :create_credit_request],
      %{params: params},
      fn ->
        result = repo.save_credit_request(params)
        {result, %{}}
      end
    )
  end
end
