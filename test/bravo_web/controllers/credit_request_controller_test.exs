defmodule BravoWeb.CreditRequestControllerTest do
  use BravoWeb.ConnCase

  import Bravo.CreditRequestsFixtures
  alias Bravo.Domain.Entities.CreditRequest

  @create_attrs %{
    status: "submitted",
    country: "ES",
    full_name: "Juan Perez",
    identity_document: "12345678Z",
    requested_amount: "1500.00",
    monthly_income: "2500.00",
    request_date: ~U[2026-06-07 21:55:00Z],
    bank_info: %{}
  }
  @update_attrs %{
    status: "approved",
    country: "ES",
    full_name: "Juan Perez Modificado",
    identity_document: "12345678Z",
    requested_amount: "2000.00",
    monthly_income: "2500.00",
    request_date: ~U[2026-06-08 21:55:00Z],
    bank_info: %{}
  }
  @invalid_attrs %{
    status: nil,
    country: nil,
    full_name: nil,
    identity_document: nil,
    requested_amount: nil,
    monthly_income: nil,
    request_date: nil,
    bank_info: nil
  }

  setup %{conn: conn} do
    # Generate token for auth
    {:ok, token} = BravoWeb.Auth.Token.generate_token("test_admin", "admin")

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("authorization", "Bearer " <> token)

    {:ok, conn: conn}
  end

  describe "index" do
    test "lists all credit_requests", %{conn: conn} do
      conn = get(conn, ~p"/api/credit_requests")
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create credit_request" do
    test "renders credit_request when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/api/credit_requests", credit_request: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, ~p"/api/credit_requests/#{id}")

      assert %{
               "id" => ^id,
               "bank_info" => %{},
               "country" => "ES",
               "full_name" => "Juan Perez",
               "identity_document" => "12345678Z",
               "monthly_income" => "2500.00",
               "requested_amount" => "1500.00",
               "status" => "submitted"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/api/credit_requests", credit_request: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update credit_request" do
    setup [:create_credit_request]

    test "renders credit_request when data is valid", %{
      conn: conn,
      credit_request: %CreditRequest{id: id} = credit_request
    } do
      conn =
        put(conn, ~p"/api/credit_requests/#{credit_request.id}", credit_request: @update_attrs)

      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, ~p"/api/credit_requests/#{id}")

      assert %{
               "id" => ^id,
               "bank_info" => %{},
               "country" => "ES",
               "full_name" => "Juan Perez Modificado",
               "identity_document" => "12345678Z",
               "monthly_income" => "2500.00",
               "requested_amount" => "2000.00",
               "status" => "approved"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, credit_request: credit_request} do
      conn =
        put(conn, ~p"/api/credit_requests/#{credit_request.id}", credit_request: @invalid_attrs)

      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete credit_request" do
    setup [:create_credit_request]

    test "deletes chosen credit_request", %{conn: conn, credit_request: credit_request} do
      conn = delete(conn, ~p"/api/credit_requests/#{credit_request.id}")
      assert response(conn, 204)

      # Requesting again should fail or result in runtime error due to context facade design raising error
      assert_raise RuntimeError, "not found", fn ->
        get(conn, ~p"/api/credit_requests/#{credit_request.id}")
      end
    end
  end

  describe "authorization" do
    test "user role can read but cannot create", %{conn: _conn} do
      conn = auth_conn("user")

      # Read is allowed
      conn = get(conn, ~p"/api/credit_requests")
      assert json_response(conn, 200)["data"] == []

      # Write is forbidden
      conn = auth_conn("user")
      conn = post(conn, ~p"/api/credit_requests", credit_request: @create_attrs)
      assert json_response(conn, 403)
    end

    test "missing token is unauthorized" do
      conn =
        Phoenix.ConnTest.build_conn()
        |> put_req_header("accept", "application/json")
        |> get(~p"/api/credit_requests")

      assert json_response(conn, 401)
    end
  end

  describe "PII masking" do
    setup [:create_credit_request]

    test "user role gets masked identity_document", %{credit_request: cr} do
      conn = auth_conn("user")
      conn = get(conn, ~p"/api/credit_requests/#{cr.id}")
      doc = json_response(conn, 200)["data"]["identity_document"]

      refute doc == "12345678Z"
      assert String.ends_with?(doc, "678Z")
      assert String.contains?(doc, "*")
    end

    test "admin role sees full identity_document", %{credit_request: cr} do
      conn = auth_conn("admin")
      conn = get(conn, ~p"/api/credit_requests/#{cr.id}")
      assert json_response(conn, 200)["data"]["identity_document"] == "12345678Z"
    end
  end

  defp auth_conn(role) do
    {:ok, token} = BravoWeb.Auth.Token.generate_token("test_user", role)

    Phoenix.ConnTest.build_conn()
    |> put_req_header("accept", "application/json")
    |> put_req_header("authorization", "Bearer " <> token)
  end

  defp create_credit_request(_) do
    credit_request = credit_request_fixture()
    %{credit_request: credit_request}
  end
end
