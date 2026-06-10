ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Bravo.Repo, :manual)

Mox.defmock(Bravo.Application.Ports.CreditRequestRepositoryMock,
  for: Bravo.Application.Ports.CreditRequestRepository
)
