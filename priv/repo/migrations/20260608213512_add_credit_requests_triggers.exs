defmodule Bravo.Repo.Migrations.AddCreditRequestsTriggers do
  use Ecto.Migration

  def up do
    # Trigger 1: Notify status changes on Channel
    execute """
    CREATE OR REPLACE FUNCTION credit_request_status_changed_notify()
    RETURNS TRIGGER AS $$
    BEGIN
      PERFORM pg_notify(
        'credit_request_status_changes',
        json_build_object(
          'id', NEW.id,
          'old_status', OLD.status,
          'new_status', NEW.status
        )::text
      );
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """

    execute """
    CREATE TRIGGER credit_request_status_trigger
    AFTER UPDATE OF status ON credit_requests
    FOR EACH ROW
    EXECUTE FUNCTION credit_request_status_changed_notify();
    """

    # Trigger 2: Enqueue Oban Job on insert
    execute """
    CREATE OR REPLACE FUNCTION credit_request_created_enqueue_job()
    RETURNS TRIGGER AS $$
    BEGIN
      INSERT INTO oban_jobs (state, queue, worker, args, max_attempts, inserted_at, scheduled_at)
      VALUES (
        'available',
        'default',
        'Bravo.Workers.RiskEvaluator',
        json_build_object('request_id', NEW.id)::jsonb,
        3,
        NOW() AT TIME ZONE 'UTC',
        NOW() AT TIME ZONE 'UTC'
      );
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """

    execute """
    CREATE TRIGGER credit_request_created_trigger
    AFTER INSERT ON credit_requests
    FOR EACH ROW
    EXECUTE FUNCTION credit_request_created_enqueue_job();
    """
  end

  def down do
    execute "DROP TRIGGER IF EXISTS credit_request_status_trigger ON credit_requests;"
    execute "DROP FUNCTION IF EXISTS credit_request_status_changed_notify();"
    execute "DROP TRIGGER IF EXISTS credit_request_created_trigger ON credit_requests;"
    execute "DROP FUNCTION IF EXISTS credit_request_created_enqueue_job();"
  end
end
