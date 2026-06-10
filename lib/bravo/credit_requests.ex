defmodule Bravo.CreditRequests do
  @moduledoc """
  The CreditRequests context facade.
  Provides an API boundary to the hexagonal core using Dependency Injection.
  """

  alias Bravo.Application.UseCases
  alias Bravo.Infrastructure.Persistence

  # Injected via configuration with a default fallback to Ecto adapter
  @repo Application.compile_env(
          :bravo,
          [__MODULE__, :repository],
          Persistence.EctoCreditRequestRepository
        )

  @default_page_size 6
  @max_page_size 50

  def list_credit_requests(filters \\ %{}) do
    UseCases.ListCreditRequests.execute(@repo, filters)
  end

  @doc """
  Lists credit requests for a page and returns pagination metadata:
  `%{entries, page, page_size, total, total_pages}`.
  """
  def paginate_credit_requests(filters \\ %{}) do
    page = max(parse_int(fetch(filters, "page"), 1), 1)

    page_size =
      parse_int(fetch(filters, "page_size"), @default_page_size) |> clamp(1, @max_page_size)

    total = @repo.count_credit_requests(filters)
    total_pages = max(div(total + page_size - 1, page_size), 1)
    page = min(page, total_pages)

    paged_filters = filters |> Map.put("page", page) |> Map.put("page_size", page_size)
    entries = list_credit_requests(paged_filters)

    %{entries: entries, page: page, page_size: page_size, total: total, total_pages: total_pages}
  end

  defp fetch(filters, key), do: Map.get(filters, key) || Map.get(filters, String.to_atom(key))

  defp parse_int(nil, default), do: default
  defp parse_int(n, _default) when is_integer(n), do: n

  defp parse_int(s, default) when is_binary(s) do
    case Integer.parse(s) do
      {n, _} -> n
      :error -> default
    end
  end

  defp clamp(n, lo, hi), do: n |> max(lo) |> min(hi)

  def get_credit_request!(id) do
    case Cachex.get(:credit_requests_cache, id) do
      {:ok, nil} ->
        case UseCases.GetCreditRequest.execute(@repo, id) do
          {:ok, record} ->
            Cachex.put(:credit_requests_cache, id, record)
            record

          {:error, :not_found} ->
            raise "not found"
        end

      {:ok, record} ->
        record
    end
  end

  def create_credit_request(attrs \\ %{}) do
    UseCases.CreateCreditRequest.execute(@repo, attrs)
  end

  def update_credit_request(id, attrs \\ %{}) do
    case UseCases.UpdateCreditRequest.execute(@repo, id, attrs) do
      {:ok, record} ->
        Cachex.del(:credit_requests_cache, id)
        {:ok, record}

      other ->
        other
    end
  end

  @doc """
  Returns the ordered status-transition audit trail for a credit request.
  """
  def list_status_history(id) do
    @repo.list_status_history(id)
  end

  def delete_credit_request(id) do
    case @repo.delete_credit_request(id) do
      :ok ->
        Cachex.del(:credit_requests_cache, id)
        :ok

      other ->
        other
    end
  end
end
