# Database seeds. Run with: mix run priv/repo/seeds.exs
#
# Idempotent for users; the credit requests are reset to a clean set of 10 each
# time so the dashboard always has representative data to show.

import Ecto.Query

alias Bravo.Accounts
alias Bravo.{CreditRequest, CreditRequests, Repo}

# --- Demo users ---

demo_users = [
  %{username: "admin", name: "Administrador", password: "admin123", role: "admin"},
  %{username: "officer", name: "Oficial de Crédito", password: "officer123", role: "officer"},
  %{username: "viewer", name: "Consulta", password: "viewer123", role: "user"}
]

for %{role: role} = attrs <- demo_users do
  case Accounts.ensure_user(attrs, role: role) do
    {:ok, user} -> IO.puts("Usuario listo: #{user.username} (#{user.role})")
    {:error, cs} -> IO.warn("No se pudo crear #{attrs.username}: #{inspect(cs.errors)}")
  end
end

# --- Credit requests (clean set of 10) ---

# Representative provider payloads per country.
es_bank = %{
  "provider" => "Iberpay ES",
  "bank_name" => "Banco Santander",
  "account_iban" => "ES9121000418451234567890",
  "credit_rating" => "A+",
  "active_debts_eur" => "1500.00",
  "validation_status" => "verified"
}

mx_bank = %{
  "provider" => "Círculo de Crédito MX",
  "bank_name" => "BBVA México",
  "account_clabe" => "012180001509230192",
  "credit_score" => 710,
  "active_debts_mxn" => "8000.00",
  "validation_status" => "verified"
}

co_bank = %{
  "provider" => "DataCrédito CO",
  "bank_name" => "Bancolombia",
  "account_number" => "CO29000123456789",
  "total_debt" => "9000000.00",
  "credit_score" => 690,
  "validation_status" => "verified"
}

# {country, full_name, document, requested_amount, monthly_income, status, bank_info, days_ago}
rows = [
  {"ES", "Lucía Fernández", "12345678Z", "3000.00", "2500.00", "submitted", nil, 0},
  {"ES", "Carlos Romero", "11111111H", "4200.00", "3100.00", "pending_review", es_bank, 1},
  {"ES", "Marta Giménez", "22222222J", "2500.00", "2800.00", "approved", es_bank, 3},
  {"ES", "Javier Ortega", "00000000T", "6000.00", "4500.00", "disbursed", es_bank, 6},
  {"MX", "Sofía García", "GARS900101HMNDFS01", "12000.00", "2500.00", "pending_review", mx_bank,
   1},
  {"MX", "Diego López", "LOPE850615MDFRRN09", "40000.00", "3000.00", "rejected", mx_bank, 2},
  {"MX", "Ana Martínez", "MARA920320HJCLLN05", "8000.00", "2200.00", "approved", mx_bank, 4},
  {"CO", "Andrés Rojas", "1012345678", "5000.00", "2000.00", "pending_review", co_bank, 1},
  {"CO", "Valentina Díaz", "79123456", "4000.00", "500.00", "rejected", co_bank, 2},
  {"CO", "Mateo Castro", "52998877", "3500.00", "1800.00", "submitted", nil, 0}
]

# Clean slate: cascade removes status history; clear the job queue too.
Repo.delete_all(CreditRequest)
Repo.delete_all("oban_jobs")

for {country, name, doc, amount, income, status, bank_info, days_ago} <- rows do
  date =
    DateTime.utc_now()
    |> DateTime.add(-days_ago * 86_400, :second)
    |> DateTime.to_iso8601()

  {:ok, cr} =
    CreditRequests.create_credit_request(%{
      "country" => country,
      "full_name" => name,
      "identity_document" => doc,
      "requested_amount" => amount,
      "monthly_income" => income,
      "status" => status,
      "bank_info" => bank_info,
      "request_date" => date
    })

  # The INSERT trigger enqueued a RiskEvaluator job; drop it so the seeded status
  # is not overwritten by a re-evaluation.
  Repo.delete_all(from(j in "oban_jobs", where: fragment("?->>'request_id' = ?", j.args, ^cr.id)))
end

IO.puts("Sembradas #{length(rows)} solicitudes de crédito")
