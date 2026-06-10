defmodule Bravo.Infrastructure.Persistence.EctoCreditRequestRepositoryTest do
  use Bravo.DataCase, async: true

  alias Bravo.Infrastructure.Persistence.EctoCreditRequestRepository
  alias Bravo.Domain.Entities.CreditRequest, as: Entity

  @valid_attrs %{
    "country" => "ES",
    "full_name" => "Juan Perez",
    "identity_document" => "12345678Z",
    "requested_amount" => Decimal.new("1500.00"),
    "monthly_income" => Decimal.new("2500.00"),
    "request_date" => DateTime.utc_now(),
    "status" => "submitted",
    "bank_info" => %{}
  }

  describe "CreditRequest persistence" do
    test "save_credit_request/1 and get_credit_request/1" do
      assert {:ok, %Entity{} = saved} =
               EctoCreditRequestRepository.save_credit_request(@valid_attrs)

      assert {:ok, ^saved} = EctoCreditRequestRepository.get_credit_request(saved.id)
    end

    test "list_credit_requests/0 returns all credit_requests" do
      {:ok, saved} = EctoCreditRequestRepository.save_credit_request(@valid_attrs)
      list = EctoCreditRequestRepository.list_credit_requests()
      assert Enum.any?(list, fn e -> e.id == saved.id end)
    end
  end
end
