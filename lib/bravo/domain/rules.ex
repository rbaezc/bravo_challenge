defmodule Bravo.Domain.Rules do
  @moduledoc """
  Pure business rules for credit request validation per country.
  """

  # Spanish DNI Regex: 8 digits followed by a control letter
  @dni_regex ~r/^[0-9]{8}[TRWAGMYFPDXBNJZSQVHLCKE]$/i

  # Mexican CURP Regex: 18 alphanumeric characters
  @curp_regex ~r/^[A-Z]{4}[0-9]{6}[HM][A-Z]{5}[A-Z0-9][0-9]$/i

  # Colombian Cédula de Ciudadanía (CC): 6 to 10 digits
  @cc_regex ~r/^[0-9]{6,10}$/

  @doc """
  Validates if the identity document format is correct for the given country.
  """
  def validate_document("ES", document) do
    if String.match?(document, @dni_regex),
      do: :ok,
      else: {:error, "Format not valid for Spanish DNI"}
  end

  def validate_document("MX", document) do
    if String.match?(document, @curp_regex),
      do: :ok,
      else: {:error, "Format not valid for Mexican CURP"}
  end

  def validate_document("CO", document) do
    if String.match?(document, @cc_regex),
      do: :ok,
      else: {:error, "Format not valid for Colombian Cédula"}
  end

  def validate_document(country, _document) do
    {:error, "Unsupported country validation: #{country}"}
  end

  @doc """
  Runs the automated **risk pre-screening** for a request.

  This is intentionally NOT a final approval: the automated step can only
  auto-reject hard failures; everything that passes is routed to `pending_review`
  so a human makes the final approve/reject decision (as in real underwriting).

  `bank_info` is the data returned by the country's bank provider (used by rules
  that depend on provider data, e.g. Colombia's debt-to-income check).

  Returns `{:ok, "rejected" | "pending_review"}` or `{:error, reason}`.
  """
  def evaluate_request(country, requested_amount, monthly_income, bank_info \\ %{})

  def evaluate_request("ES", _requested_amount, _monthly_income, _bank_info) do
    # Spain: no hard auto-reject rule here. Amounts over the threshold are
    # flagged as "subject to additional review"; everything else is also routed
    # to manual review rather than auto-approved.
    {:ok, "pending_review"}
  end

  def evaluate_request("MX", requested_amount, monthly_income, _bank_info) do
    # Mexico hard rule: requested amount cannot exceed 10x the monthly income.
    max_amount = Decimal.mult(monthly_income, Decimal.new("10.00"))

    if Decimal.gt?(requested_amount, max_amount) do
      # Hard failure -> auto-reject.
      {:ok, "rejected"}
    else
      # Passed screening -> awaits a human decision.
      {:ok, "pending_review"}
    end
  end

  def evaluate_request("CO", _requested_amount, monthly_income, bank_info) do
    # Colombia hard rule: uses the TOTAL DEBT reported by the bank provider.
    # If total debt exceeds 12x the monthly income, the applicant is considered
    # over-indebted -> auto-reject. Otherwise it goes to manual review.
    total_debt = bank_info_decimal(bank_info, :total_debt)
    max_debt = Decimal.mult(monthly_income, Decimal.new("12"))

    if Decimal.gt?(total_debt, max_debt) do
      {:ok, "rejected"}
    else
      {:ok, "pending_review"}
    end
  end

  def evaluate_request(country, _requested_amount, _monthly_income, _bank_info) do
    {:error, "Unsupported country rules: #{country}"}
  end

  # Reads a Decimal value from bank_info accepting atom or string keys.
  defp bank_info_decimal(bank_info, key) do
    value = Map.get(bank_info, key) || Map.get(bank_info, to_string(key)) || 0

    case Decimal.cast(value) do
      {:ok, decimal} -> decimal
      _ -> Decimal.new(0)
    end
  end
end
