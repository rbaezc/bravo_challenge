defmodule Bravo.Application.UseCases.ListCreditRequests do
  @moduledoc """
  Use case to list credit_requests.
  """

  def execute(repo, filters \\ %{}) do
    :telemetry.span(
      [:bravo, :use_case, :list_credit_requests],
      %{filters: filters},
      fn ->
        result = repo.list_credit_requests(filters)
        {result, %{}}
      end
    )
  end
end
