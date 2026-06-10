defmodule Bravo.Workers.RiskEvaluator do
  @moduledoc """
  Oban worker that runs in the background to evaluate credit request risk.
  Fetches banking info from the provider, runs country-specific rules,
  and updates the request status.
  """
  use Oban.Worker, queue: :default

  alias Bravo.CreditRequests
  alias Bravo.Infrastructure.BankProvider.Factory, as: BankProviderFactory
  alias Bravo.Domain.Rules, as: DomainRules

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"request_id" => request_id}}) do
    Logger.info("Starting background risk evaluation for Credit Request: #{request_id}")

    try do
      request = CreditRequests.get_credit_request!(request_id)

      # Determine bank provider adapter based on country
      case BankProviderFactory.get_adapter(request.country) do
        {:ok, adapter} ->
          # Fetch customer bank details from provider
          case adapter.fetch_customer_info(request.identity_document) do
            {:ok, bank_info} ->
              # Evaluate business rules using country logic (some rules, like
              # Colombia's, depend on the provider's bank_info).
              case DomainRules.evaluate_request(
                     request.country,
                     request.requested_amount,
                     request.monthly_income,
                     bank_info
                   ) do
                {:ok, new_status} ->
                  Logger.info(
                    "Evaluation complete for #{request_id}: status set to #{new_status}"
                  )

                  # Update the request with evaluated status and bank info
                  {:ok, _updated_request} =
                    CreditRequests.update_credit_request(request_id, %{
                      status: new_status,
                      bank_info: bank_info
                    })

                  # Broadcast status change for real-time frontend update.
                  # The outbound webhook/notification is handled asynchronously by
                  # Bravo.Workers.StatusNotifier, enqueued by a DB trigger on the
                  # status change (runs on the separate :notifications queue).
                  Phoenix.PubSub.broadcast(
                    Bravo.PubSub,
                    "credit_requests",
                    {:credit_request_updated, request_id}
                  )

                  :ok

                {:error, reason} ->
                  Logger.error("Rules evaluation failed for #{request_id}: #{inspect(reason)}")
                  # Hard reject on rule failure
                  {:ok, _} =
                    CreditRequests.update_credit_request(request_id, %{status: "rejected"})

                  :ok
              end

            {:error, :invalid_document_format} ->
              Logger.warning("Invalid document format for #{request_id}")
              {:ok, _} = CreditRequests.update_credit_request(request_id, %{status: "rejected"})
              :ok

            {:error, temp_reason} ->
              # Temporary error from provider -> Raise so Oban retries!
              Logger.error(
                "Temporary banking provider error for #{request_id}: #{inspect(temp_reason)}"
              )

              raise "Banking provider temporary error: #{inspect(temp_reason)}"
          end

        {:error, reason} ->
          Logger.error(
            "Failed to get bank adapter for country #{request.country}: #{inspect(reason)}"
          )

          {:ok, _} = CreditRequests.update_credit_request(request_id, %{status: "rejected"})
          :ok
      end
    rescue
      e ->
        Logger.error("Error evaluating credit request #{request_id}: #{inspect(e)}")
        reraise e, __STACKTRACE__
    end
  end
end
