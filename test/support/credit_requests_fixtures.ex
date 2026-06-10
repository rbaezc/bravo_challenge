defmodule Bravo.CreditRequestsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Bravo.CreditRequests` context.
  """

  def credit_request_fixture(attrs \\ %{}) do
    valid_attrs = %{
      "country" => "ES",
      "full_name" => "Juan Perez",
      "identity_document" => "12345678Z",
      "requested_amount" => Decimal.new("1500.00"),
      "monthly_income" => Decimal.new("2500.00"),
      "request_date" => "2026-06-08T12:00:00Z",
      "status" => "submitted"
    }

    # Normalize keys to string
    normalized_attrs =
      attrs
      |> Map.new(fn {k, v} -> {to_string(k), v} end)
      |> Map.reject(fn {_k, v} -> is_nil(v) end)

    final_attrs = Map.merge(valid_attrs, normalized_attrs)

    {:ok, credit_request} = Bravo.CreditRequests.create_credit_request(final_attrs)
    credit_request
  end
end
