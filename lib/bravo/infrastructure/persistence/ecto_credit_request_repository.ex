defmodule Bravo.Infrastructure.Persistence.EctoCreditRequestRepository do
  @moduledoc """
  Adapter implementing CreditRequestRepository using Ecto.
  """
  @behaviour Bravo.Application.Ports.CreditRequestRepository

  import Ecto.Query

  alias Bravo.Domain.Entities.CreditRequest, as: Entity
  alias Bravo.CreditRequest, as: Schema
  alias Bravo.CreditRequestStatusHistory, as: HistorySchema
  alias Bravo.Repo

  @impl true
  def get_credit_request(id) do
    case Repo.get(Schema, id) do
      nil -> {:error, :not_found}
      record -> {:ok, to_domain(record)}
    end
  end

  @impl true
  def list_credit_requests(filters \\ %{}) do
    Schema
    |> apply_filters(filters)
    |> order_by(desc: :inserted_at)
    |> paginate(filters)
    |> Repo.all()
    |> Enum.map(&to_domain/1)
  end

  @impl true
  def count_credit_requests(filters \\ %{}) do
    Schema
    |> apply_filters(filters)
    |> Repo.aggregate(:count)
  end

  # Applies the country / status / date-range filters shared by list and count.
  defp apply_filters(query, filters) do
    query
    |> filter_eq(:country, fetch(filters, :country))
    |> filter_eq(:status, fetch(filters, :status))
    |> filter_date(:>=, fetch(filters, :start_date), ~T[00:00:00.000])
    |> filter_date(:<=, fetch(filters, :end_date), ~T[23:59:59.999])
  end

  defp fetch(filters, key), do: Map.get(filters, key) || Map.get(filters, to_string(key))

  defp filter_eq(query, _field, blank) when blank in [nil, ""], do: query

  defp filter_eq(query, field, value),
    do: from(q in query, where: field(q, ^field) == ^to_string(value))

  defp filter_date(query, _op, blank, _time) when blank in [nil, ""], do: query

  defp filter_date(query, op, value, time) do
    case Date.from_iso8601(to_string(value)) do
      {:ok, date} ->
        dt = DateTime.new!(date, time, "Etc/UTC")

        if op == :>=,
          do: from(q in query, where: q.request_date >= ^dt),
          else: from(q in query, where: q.request_date <= ^dt)

      _ ->
        query
    end
  end

  # Applies LIMIT/OFFSET only when a positive page_size is given.
  defp paginate(query, filters) do
    page_size = to_int(fetch(filters, :page_size))
    page = max(to_int(fetch(filters, :page)) || 1, 1)

    if page_size && page_size > 0 do
      from(q in query, limit: ^page_size, offset: ^((page - 1) * page_size))
    else
      query
    end
  end

  defp to_int(nil), do: nil
  defp to_int(n) when is_integer(n), do: n

  defp to_int(s) when is_binary(s) do
    case Integer.parse(s) do
      {n, _} -> n
      :error -> nil
    end
  end

  @impl true
  def save_credit_request(params) do
    id = Map.get(params, :id) || Map.get(params, "id")
    struct = if(id, do: Repo.get(Schema, id) || %Schema{id: id}, else: %Schema{})

    # Normalize to string keys (avoid Ecto CastError on mixed keys) and drop :id.
    attrs =
      params
      |> Map.drop([:id, "id"])
      |> Map.new(fn {k, v} -> {to_string(k), v} end)

    struct
    |> Schema.changeset(attrs)
    |> Repo.insert_or_update()
    |> case do
      {:ok, record} -> {:ok, to_domain(record)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @impl true
  def delete_credit_request(id) do
    case Repo.get(Schema, id) do
      nil -> {:error, :not_found}
      record -> with {:ok, _} <- Repo.delete(record), do: :ok
    end
  end

  @impl true
  def list_status_history(id) do
    from(h in HistorySchema,
      where: h.credit_request_id == ^id,
      order_by: [asc: h.inserted_at, asc: h.id]
    )
    |> Repo.all()
    |> Enum.map(fn h ->
      %{old_status: h.old_status, new_status: h.new_status, changed_at: h.inserted_at}
    end)
  end

  defp to_domain(record) do
    struct(Entity, Map.from_struct(record))
  end
end
