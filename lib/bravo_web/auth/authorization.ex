defmodule BravoWeb.Auth.Authorization do
  @moduledoc """
  Basic role-based authorization policy.

  Roles (decoded from the JWT `role` claim):
    * `"admin"`   - full access (read + write + decisions).
    * `"officer"` - read + write (create/update/delete) credit requests.
    * `"user"`    - read-only access.

  This keeps "who can see or modify what" in a single place so controllers
  and LiveViews can share the same policy.
  """

  @write_roles ~w(admin officer)
  @decision_roles ~w(admin)

  @doc """
  Returns true if the given role is allowed to perform `action`.

  Actions:
    * `:read`     - list / show a credit request.
    * `:write`    - create / update / delete a credit request.
    * `:decide`   - approve / reject a request in manual review.
  """
  def can?(_role, :read), do: true
  def can?(role, :write), do: role in @write_roles
  def can?(role, :decide), do: role in @decision_roles
  def can?(_role, _action), do: false

  @doc """
  Returns true when the role is privileged enough to view unmasked PII
  (e.g. the full identity document).
  """
  def can_view_pii?(role), do: role in @write_roles
end
