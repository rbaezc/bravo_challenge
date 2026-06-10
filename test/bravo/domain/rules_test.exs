defmodule Bravo.Domain.RulesTest do
  use ExUnit.Case, async: true

  alias Bravo.Domain.Rules

  describe "validate_document/2" do
    test "accepts a well-formed Spanish DNI, Mexican CURP and Colombian Cédula" do
      assert Rules.validate_document("ES", "12345678Z") == :ok
      assert Rules.validate_document("MX", "GARS900101HMNDFS01") == :ok
      assert Rules.validate_document("CO", "1012345678") == :ok
    end

    test "rejects malformed documents" do
      assert {:error, _} = Rules.validate_document("ES", "ABC")
      assert {:error, _} = Rules.validate_document("MX", "123")
      assert {:error, _} = Rules.validate_document("CO", "12AB")
    end
  end

  describe "evaluate_request/3 (automated risk pre-screening, never auto-approves)" do
    test "Spain routes to manual review (no auto-approval)" do
      assert Rules.evaluate_request("ES", Decimal.new("1000"), Decimal.new("3000")) ==
               {:ok, "pending_review"}

      # even a large amount only triggers review, never rejection here
      assert Rules.evaluate_request("ES", Decimal.new("999999"), Decimal.new("3000")) ==
               {:ok, "pending_review"}
    end

    test "Mexico auto-rejects when the amount exceeds 10x the monthly income" do
      assert Rules.evaluate_request("MX", Decimal.new("50000"), Decimal.new("3000")) ==
               {:ok, "rejected"}
    end

    test "Mexico routes a passing request to manual review (no auto-approval)" do
      assert Rules.evaluate_request("MX", Decimal.new("10000"), Decimal.new("3000")) ==
               {:ok, "pending_review"}
    end

    test "Colombia uses the provider's total debt vs income (debt-to-income)" do
      # total_debt > 12x income -> over-indebted -> rejected
      assert Rules.evaluate_request("CO", Decimal.new("5000"), Decimal.new("500000"), %{
               total_debt: Decimal.new("9000000")
             }) == {:ok, "rejected"}

      # within the debt-to-income limit -> manual review
      assert Rules.evaluate_request("CO", Decimal.new("5000"), Decimal.new("2000000"), %{
               total_debt: Decimal.new("9000000")
             }) == {:ok, "pending_review"}
    end

    test "never returns approved automatically" do
      for {country, doc_amount} <- [{"ES", "1000"}, {"MX", "1000"}] do
        {:ok, status} =
          Rules.evaluate_request(country, Decimal.new(doc_amount), Decimal.new("3000"))

        refute status == "approved"
      end
    end
  end
end
