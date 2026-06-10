defmodule Bravo.WorkflowTest do
  use Bravo.DataCase, async: true

  import Bravo.CreditRequestsFixtures

  alias Bravo.CreditRequests
  alias Bravo.Workflow

  describe "seeded default workflow" do
    test "exposes the default statuses" do
      keys = Workflow.statuses()
      assert "submitted" in keys
      assert "approved" in keys
      assert "disbursed" in keys
      refute "frozen" in keys
    end

    test "valid_status?/1" do
      assert Workflow.valid_status?("submitted")
      refute Workflow.valid_status?("frozen")
    end

    test "initial_statuses/0" do
      assert Workflow.initial_statuses() == ["submitted"]
    end

    test "per-country transitions (ES can disburse, MX cannot)" do
      assert Workflow.can_transition?("ES", "approved", "disbursed")
      refute Workflow.can_transition?("MX", "approved", "disbursed")
    end

    test "manual_transitions/2 reflects the data" do
      assert Workflow.manual_transitions("MX", "pending_review")
             |> Enum.map(& &1.to)
             |> Enum.sort() == ["approved", "rejected"]

      assert Workflow.manual_transitions("ES", "approved") == [
               %{to: "disbursed", label: "Desembolsar"}
             ]

      assert Workflow.manual_transitions("MX", "approved") == []
      # submitted -> * are automatic (not manual)
      assert Workflow.manual_transitions("MX", "submitted") == []
    end
  end

  describe "runtime extension (no deploy)" do
    test "a status and transition added at runtime are honored end-to-end" do
      {:ok, _} =
        Workflow.upsert_status(%{
          key: "cancelled",
          label: "Cancelado",
          color: "slate",
          is_terminal: true,
          position: 10
        })

      {:ok, _} =
        Workflow.add_transition(%{
          from_status: "submitted",
          to_status: "cancelled",
          manual: true,
          action_label: "Cancelar"
        })

      # The state machine now recognizes the new state/transition...
      assert "cancelled" in Workflow.statuses()
      assert Workflow.can_transition?("MX", "submitted", "cancelled")

      # ...and a real credit request can move into it (validated by the changeset).
      cr =
        credit_request_fixture(%{"country" => "MX", "identity_document" => "GARS900101HMNDFS01"})

      assert {:ok, updated} = CreditRequests.update_credit_request(cr.id, %{status: "cancelled"})
      assert updated.status == "cancelled"
    end

    test "transitions still rejected when not defined" do
      cr = credit_request_fixture()
      {:ok, _} = CreditRequests.update_credit_request(cr.id, %{status: "approved"})

      # approved -> submitted is not a defined transition
      assert {:error, changeset} =
               CreditRequests.update_credit_request(cr.id, %{status: "submitted"})

      assert %{status: ["invalid transition from 'approved' to 'submitted'"]} =
               errors_on(changeset)
    end
  end
end
