defmodule BravoWeb.CreditRequestController do
  use BravoWeb, :controller

  alias Bravo.CreditRequests
  alias Bravo.Domain.Entities.CreditRequest
  alias BravoWeb.Auth.Authorization

  action_fallback BravoWeb.FallbackController

  def index(conn, params) do
    with :ok <- authorize(conn, :read) do
      page = CreditRequests.paginate_credit_requests(params)
      render(conn, :index, page: page, role: role(conn))
    end
  end

  def create(conn, %{"credit_request" => credit_request_params}) do
    # Merge defaults for status and request_date
    params =
      credit_request_params
      |> Map.put_new("status", "submitted")
      |> Map.put_new("request_date", DateTime.utc_now() |> DateTime.to_iso8601())

    with :ok <- authorize(conn, :write),
         {:ok, %CreditRequest{} = credit_request} <- CreditRequests.create_credit_request(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/credit_requests/#{credit_request.id}")
      |> render(:show, credit_request: credit_request, role: role(conn))
    end
  end

  def show(conn, %{"id" => id}) do
    with :ok <- authorize(conn, :read) do
      credit_request = CreditRequests.get_credit_request!(id)
      render(conn, :show, credit_request: credit_request, role: role(conn))
    end
  end

  def update(conn, %{"id" => id, "credit_request" => credit_request_params}) do
    with :ok <- authorize(conn, :write),
         {:ok, %CreditRequest{} = credit_request} <-
           CreditRequests.update_credit_request(id, credit_request_params) do
      render(conn, :show, credit_request: credit_request, role: role(conn))
    end
  end

  def delete(conn, %{"id" => id}) do
    with :ok <- authorize(conn, :write),
         :ok <- CreditRequests.delete_credit_request(id) do
      send_resp(conn, :no_content, "")
    end
  end

  # --- Authorization helpers ---

  defp role(conn), do: conn.assigns[:current_role]

  defp authorize(conn, action) do
    if Authorization.can?(role(conn), action), do: :ok, else: {:error, :forbidden}
  end
end
