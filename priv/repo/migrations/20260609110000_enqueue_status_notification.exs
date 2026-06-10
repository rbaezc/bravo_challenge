defmodule Bravo.Repo.Migrations.EnqueueStatusNotification do
  use Ecto.Migration

  @moduledoc """
  Extends the status-change trigger so each transition also enqueues a
  `Bravo.Workers.StatusNotifier` job on the `:notifications` queue (a second
  async flow, parallel to the `:default` risk-evaluation queue).
  """

  def up do
    execute """
    CREATE OR REPLACE FUNCTION credit_request_status_changed_notify()
    RETURNS TRIGGER AS $$
    BEGIN
      IF NEW.status IS DISTINCT FROM OLD.status THEN
        -- Audit trail
        INSERT INTO credit_request_status_history (credit_request_id, old_status, new_status, inserted_at)
        VALUES (NEW.id, OLD.status, NEW.status, NOW() AT TIME ZONE 'UTC');

        -- Real-time UI notification
        PERFORM pg_notify(
          'credit_request_status_changes',
          json_build_object(
            'id', NEW.id,
            'old_status', OLD.status,
            'new_status', NEW.status
          )::text
        );

        -- Async outbound notification job (separate :notifications queue)
        INSERT INTO oban_jobs (state, queue, worker, args, max_attempts, inserted_at, scheduled_at)
        VALUES (
          'available',
          'notifications',
          'Bravo.Workers.StatusNotifier',
          json_build_object(
            'request_id', NEW.id,
            'old_status', OLD.status,
            'new_status', NEW.status
          )::jsonb,
          3,
          NOW() AT TIME ZONE 'UTC',
          NOW() AT TIME ZONE 'UTC'
        );
      END IF;
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """
  end

  def down do
    # Restore the previous version (audit + pg_notify, without enqueueing notifications).
    execute """
    CREATE OR REPLACE FUNCTION credit_request_status_changed_notify()
    RETURNS TRIGGER AS $$
    BEGIN
      IF NEW.status IS DISTINCT FROM OLD.status THEN
        INSERT INTO credit_request_status_history (credit_request_id, old_status, new_status, inserted_at)
        VALUES (NEW.id, OLD.status, NEW.status, NOW() AT TIME ZONE 'UTC');

        PERFORM pg_notify(
          'credit_request_status_changes',
          json_build_object(
            'id', NEW.id,
            'old_status', OLD.status,
            'new_status', NEW.status
          )::text
        );
      END IF;
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """
  end
end
