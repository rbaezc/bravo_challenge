defmodule Bravo.Repo.Migrations.AddStatusHistory do
  use Ecto.Migration

  @moduledoc """
  Status-transition audit trail via triggers: initial status recorded on INSERT,
  every change recorded on UPDATE (which still emits pg_notify).
  """

  def up do
    create table(:credit_request_status_history) do
      add :credit_request_id,
          references(:credit_requests, type: :binary_id, on_delete: :delete_all),
          null: false

      add :old_status, :string
      add :new_status, :string, null: false

      timestamps(updated_at: false, type: :utc_datetime)
    end

    create index(:credit_request_status_history, [:credit_request_id, :inserted_at])

    # Extend the existing status-change function to also record an audit row.
    # Guarded by IS DISTINCT FROM so no-op updates are not logged.
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

    # Record the initial status when a request is created.
    execute """
    CREATE OR REPLACE FUNCTION credit_request_status_history_initial()
    RETURNS TRIGGER AS $$
    BEGIN
      INSERT INTO credit_request_status_history (credit_request_id, old_status, new_status, inserted_at)
      VALUES (NEW.id, NULL, NEW.status, NOW() AT TIME ZONE 'UTC');
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """

    execute """
    CREATE TRIGGER credit_request_status_history_initial_trigger
    AFTER INSERT ON credit_requests
    FOR EACH ROW
    EXECUTE FUNCTION credit_request_status_history_initial();
    """
  end

  def down do
    execute "DROP TRIGGER IF EXISTS credit_request_status_history_initial_trigger ON credit_requests;"
    execute "DROP FUNCTION IF EXISTS credit_request_status_history_initial();"

    # Restore the original notify-only function (no history insert).
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

    drop table(:credit_request_status_history)
  end
end
