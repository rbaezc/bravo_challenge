defmodule Bravo.Repo.Migrations.CreateWorkflowTables do
  use Ecto.Migration

  @moduledoc """
  Data-driven state machine: statuses and allowed transitions live in tables, so
  new states/flows can be added at runtime without a deploy. The default workflow
  is seeded here as reference data (also so tests, which only migrate, have it).
  """

  def up do
    create table(:credit_statuses) do
      add :key, :string, null: false
      add :label, :string, null: false
      add :color, :string, null: false, default: "slate"
      add :is_initial, :boolean, null: false, default: false
      add :is_terminal, :boolean, null: false, default: false
      add :position, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create unique_index(:credit_statuses, [:key])

    create table(:credit_status_transitions) do
      add :from_status, :string, null: false
      add :to_status, :string, null: false
      # NULL country = default flow (applies to every country unless overridden).
      add :country, :string
      # manual = triggered by a human from the UI (vs. automatic, by a worker).
      add :manual, :boolean, null: false, default: false
      add :action_label, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:credit_status_transitions, [:from_status, :to_status, :country],
             name: :credit_status_transitions_unique
           )

    # --- Seed the default workflow (reference data) ---
    execute """
    INSERT INTO credit_statuses (key, label, color, is_initial, is_terminal, position, inserted_at, updated_at) VALUES
      ('submitted',      'Enviado',         'blue',    true,  false, 1, NOW(), NOW()),
      ('pending_review', 'Revisión Manual', 'amber',   false, false, 2, NOW(), NOW()),
      ('approved',       'Aprobado',        'emerald', false, false, 3, NOW(), NOW()),
      ('rejected',       'Rechazado',       'rose',    false, true,  4, NOW(), NOW()),
      ('disbursed',      'Desembolsado',    'cyan',    false, true,  5, NOW(), NOW());
    """

    execute """
    INSERT INTO credit_status_transitions (from_status, to_status, country, manual, action_label, inserted_at, updated_at) VALUES
      -- automatic transitions performed by the risk-evaluation worker
      ('submitted',      'pending_review', NULL, false, NULL, NOW(), NOW()),
      ('submitted',      'approved',       NULL, false, NULL, NOW(), NOW()),
      ('submitted',      'rejected',       NULL, false, NULL, NOW(), NOW()),
      -- manual decisions from the dashboard
      ('pending_review', 'approved',       NULL, true,  'Aprobar',     NOW(), NOW()),
      ('pending_review', 'rejected',       NULL, true,  'Rechazar',    NOW(), NOW()),
      -- Spain-specific post-approval disbursement step
      ('approved',       'disbursed',      'ES', true,  'Desembolsar', NOW(), NOW());
    """
  end

  def down do
    drop table(:credit_status_transitions)
    drop table(:credit_statuses)
  end
end
