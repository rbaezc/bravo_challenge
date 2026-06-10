defmodule Bravo.Domain.Entities.CreditRequest do
  @moduledoc """
  The CreditRequest domain entity.
  """

  defstruct [
    :id
    | [
        :country,
        :full_name,
        :identity_document,
        :requested_amount,
        :monthly_income,
        :request_date,
        :status,
        :bank_info
      ]
  ]

  @type t :: %__MODULE__{
          id: term(),
          country: term(),
          full_name: term(),
          identity_document: term(),
          requested_amount: term(),
          monthly_income: term(),
          request_date: term(),
          status: term(),
          bank_info: term()
        }
end
