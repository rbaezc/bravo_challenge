defmodule Bravo.Application.UseCases.UpdateCreditRequest do
  @moduledoc """
  Use case to update an existing credit request.
  """

  def execute(repo, id, params) do
    :telemetry.span(
      [:bravo, :use_case, :update_credit_request],
      %{id: id, params: params},
      fn ->
        # Merge the id into params to trigger update logic in the repo
        update_params = Map.put(params, :id, id)
        result = repo.save_credit_request(update_params)
        {result, %{}}
      end
    )
  end
end
