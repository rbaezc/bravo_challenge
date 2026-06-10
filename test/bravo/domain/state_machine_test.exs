defmodule Bravo.Domain.StateMachineTest do
  use ExUnit.Case, async: true

  alias Bravo.Domain.StateMachine

  # A sample transition table mirroring the seeded default workflow, with a
  # Spain-specific override (approved -> disbursed).
  @transitions %{
    nil => %{
      "submitted" => ~w(pending_review approved rejected),
      "pending_review" => ~w(approved rejected)
    },
    "ES" => %{
      "approved" => ~w(disbursed)
    }
  }

  describe "can_transition?/4" do
    test "allows valid transitions from submitted" do
      assert StateMachine.can_transition?(@transitions, "ES", "submitted", "pending_review")
      assert StateMachine.can_transition?(@transitions, "MX", "submitted", "approved")
      assert StateMachine.can_transition?(@transitions, "MX", "submitted", "rejected")
    end

    test "allows decisions from pending_review" do
      assert StateMachine.can_transition?(@transitions, "MX", "pending_review", "approved")
      assert StateMachine.can_transition?(@transitions, "MX", "pending_review", "rejected")
    end

    test "treats states with no outgoing transitions as terminal" do
      refute StateMachine.can_transition?(@transitions, "ES", "rejected", "approved")
      refute StateMachine.can_transition?(@transitions, "MX", "approved", "rejected")
    end

    test "allows no-op transitions (same status)" do
      assert StateMachine.can_transition?(@transitions, "ES", "approved", "approved")
      assert StateMachine.can_transition?(@transitions, "MX", "submitted", "submitted")
    end

    test "applies the per-country override (ES can disburse, MX cannot)" do
      assert StateMachine.can_transition?(@transitions, "ES", "approved", "disbursed")
      refute StateMachine.can_transition?(@transitions, "MX", "approved", "disbursed")
    end
  end

  describe "allowed_transitions/3" do
    test "merges default flow with the country override per from-state" do
      assert StateMachine.allowed_transitions(@transitions, "ES", "approved") == ~w(disbursed)
      assert StateMachine.allowed_transitions(@transitions, "MX", "approved") == []

      assert StateMachine.allowed_transitions(@transitions, "ES", "submitted") ==
               ~w(pending_review approved rejected)
    end
  end
end
