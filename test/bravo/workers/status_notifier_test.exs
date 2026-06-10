defmodule Bravo.Workers.StatusNotifierTest do
  use Bravo.DataCase, async: true
  use Oban.Testing, repo: Bravo.Repo

  import Bravo.CreditRequestsFixtures

  alias Bravo.CreditRequests

  test "creating a request enqueues RiskEvaluator on the :default queue (via DB trigger)" do
    cr = credit_request_fixture()

    assert_enqueued(
      worker: Bravo.Workers.RiskEvaluator,
      queue: :default,
      args: %{request_id: cr.id}
    )
  end

  test "a status change enqueues StatusNotifier on the :notifications queue (via DB trigger)" do
    cr = credit_request_fixture()
    {:ok, _} = CreditRequests.update_credit_request(cr.id, %{status: "approved"})

    # The two queues are independent: notifications run in parallel with evaluation.
    assert_enqueued(
      worker: Bravo.Workers.StatusNotifier,
      queue: :notifications,
      args: %{request_id: cr.id, old_status: "submitted", new_status: "approved"}
    )
  end

  test "no notification job is enqueued when the status does not change" do
    cr = credit_request_fixture()
    {:ok, _} = CreditRequests.update_credit_request(cr.id, %{full_name: "Otro Nombre"})

    refute_enqueued(worker: Bravo.Workers.StatusNotifier, args: %{request_id: cr.id})
  end
end
