defmodule Bravo.Application.UseCases.CreateCreditRequestTest do
  use ExUnit.Case, async: true
  import Mox

  alias Bravo.Application.UseCases.CreateCreditRequest
  alias Bravo.Domain.Entities.CreditRequest

  @repo_mock Bravo.Application.Ports.CreditRequestRepositoryMock

  setup :verify_on_exit!

  test "execute/2 calls the repository to save a credit_request" do
    params = %{
      "country" => "ES",
      "full_name" => "Test User",
      "identity_document" => "12345678Z",
      "requested_amount" => Decimal.new("1000.00"),
      "monthly_income" => Decimal.new("2000.00"),
      "request_date" => "2026-06-08T12:00:00Z",
      "status" => "submitted"
    }

    expected_entity = %CreditRequest{
      id: "123",
      country: "ES",
      full_name: "Test User",
      identity_document: "12345678Z",
      requested_amount: Decimal.new("1000.00"),
      monthly_income: Decimal.new("2000.00"),
      request_date: "2026-06-08T12:00:00Z",
      status: "submitted"
    }

    expect(@repo_mock, :save_credit_request, fn ^params ->
      {:ok, expected_entity}
    end)

    assert {:ok, ^expected_entity} = CreateCreditRequest.execute(@repo_mock, params)
  end
end
