defmodule Bravo.StatusHistoryTest do
  use Bravo.DataCase, async: true

  import Bravo.CreditRequestsFixtures

  alias Bravo.CreditRequests

  describe "status history audit trail (Postgres triggers)" do
    test "records the initial status on creation" do
      cr = credit_request_fixture()

      assert [%{old_status: nil, new_status: "submitted"}] =
               CreditRequests.list_status_history(cr.id)
    end

    test "appends an entry on each status change" do
      cr = credit_request_fixture()
      {:ok, _} = CreditRequests.update_credit_request(cr.id, %{status: "approved"})

      history = CreditRequests.list_status_history(cr.id)

      assert [
               %{old_status: nil, new_status: "submitted"},
               %{old_status: "submitted", new_status: "approved"}
             ] = history
    end

    test "does not log no-op updates (status unchanged)" do
      cr = credit_request_fixture()
      # Update a non-status field only.
      {:ok, _} = CreditRequests.update_credit_request(cr.id, %{full_name: "Nuevo Nombre"})

      assert [%{new_status: "submitted"}] = CreditRequests.list_status_history(cr.id)
    end
  end

  describe "per-country flow (ES disbursed)" do
    test "Spain can move approved -> disbursed" do
      cr = credit_request_fixture(%{"country" => "ES", "identity_document" => "12345678Z"})
      {:ok, _} = CreditRequests.update_credit_request(cr.id, %{status: "approved"})

      assert {:ok, updated} =
               CreditRequests.update_credit_request(cr.id, %{status: "disbursed"})

      assert updated.status == "disbursed"
    end

    test "Mexico cannot move approved -> disbursed (invalid transition)" do
      cr =
        credit_request_fixture(%{
          "country" => "MX",
          "identity_document" => "GARS900101HMNDFS01"
        })

      {:ok, _} = CreditRequests.update_credit_request(cr.id, %{status: "approved"})

      assert {:error, changeset} =
               CreditRequests.update_credit_request(cr.id, %{status: "disbursed"})

      assert %{status: ["invalid transition from 'approved' to 'disbursed'"]} =
               errors_on(changeset)
    end
  end
end
