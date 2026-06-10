defmodule BravoWeb.CreditRequestJSON do
  alias Bravo.Domain.Entities.CreditRequest
  alias BravoWeb.Auth.Authorization

  @doc """
  Renders a list of credit_requests.
  """
  def index(%{page: page} = assigns) do
    role = Map.get(assigns, :role)

    %{
      data: for(credit_request <- page.entries, do: data(credit_request, role)),
      meta: %{
        page: page.page,
        page_size: page.page_size,
        total: page.total,
        total_pages: page.total_pages
      }
    }
  end

  @doc """
  Renders a single credit_request.
  """
  def show(%{credit_request: credit_request} = assigns) do
    %{data: data(credit_request, Map.get(assigns, :role))}
  end

  defp data(%CreditRequest{} = credit_request, role) do
    # Bank account numbers (IBAN/CLABE) are always masked regardless of role.
    # The identity document is only exposed in full to privileged roles.
    %{
      id: credit_request.id,
      country: credit_request.country,
      full_name: credit_request.full_name,
      identity_document: mask_identity_document(credit_request.identity_document, role),
      requested_amount: credit_request.requested_amount,
      monthly_income: credit_request.monthly_income,
      request_date: credit_request.request_date,
      status: credit_request.status,
      bank_info: mask_bank_info(credit_request.bank_info)
    }
  end

  # Privileged roles (admin/officer) see the full document; everyone else gets it masked.
  defp mask_identity_document(document, role) do
    if Authorization.can_view_pii?(role) do
      document
    else
      mask_string(document, 4)
    end
  end

  defp mask_bank_info(nil), do: nil

  defp mask_bank_info(bank_info) when is_map(bank_info) do
    # Mask sensitive details like IBAN or CLABE to protect PII
    masked_info =
      cond do
        Map.has_key?(bank_info, "account_iban") or Map.has_key?(bank_info, :account_iban) ->
          iban = Map.get(bank_info, "account_iban") || Map.get(bank_info, :account_iban)
          Map.put(bank_info, "account_iban", mask_string(iban, 4))

        Map.has_key?(bank_info, "account_clabe") or Map.has_key?(bank_info, :account_clabe) ->
          clabe = Map.get(bank_info, "account_clabe") || Map.get(bank_info, :account_clabe)
          Map.put(bank_info, "account_clabe", mask_string(clabe, 4))

        Map.has_key?(bank_info, "account_number") or Map.has_key?(bank_info, :account_number) ->
          number = Map.get(bank_info, "account_number") || Map.get(bank_info, :account_number)
          Map.put(bank_info, "account_number", mask_string(number, 4))

        true ->
          bank_info
      end

    # Clean map keys to string keys for JSON serialization
    for {k, v} <- masked_info, into: %{}, do: {to_string(k), v}
  end

  defp mask_bank_info(other), do: other

  defp mask_string(nil, _), do: nil

  defp mask_string(str, visible_suffix_len) do
    len = String.length(str)

    if len > visible_suffix_len do
      prefix = String.duplicate("*", len - visible_suffix_len)
      suffix = String.slice(str, -visible_suffix_len..-1)
      prefix <> suffix
    else
      str
    end
  end
end
