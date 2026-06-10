defmodule Bravo.Accounts do
  @moduledoc """
  The Accounts context: user registration and password authentication,
  backed by the database with bcrypt-hashed passwords.
  """
  import Ecto.Query, warn: false

  alias Bravo.Repo
  alias Bravo.Accounts.User

  @doc "Fetches a user by id, raising if not found."
  def get_user!(id), do: Repo.get!(User, id)

  @doc "Fetches a user by username (case-insensitive), or nil."
  def get_user_by_username(username) when is_binary(username) do
    Repo.get_by(User, username: String.downcase(username))
  end

  @doc """
  Authenticates by username + password.

  Returns the `%User{}` on success, or `nil` on failure. Always runs a bcrypt
  check (even when the user does not exist) to keep timing constant.
  """
  def get_user_by_username_and_password(username, password)
      when is_binary(username) and is_binary(password) do
    user = get_user_by_username(username)
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Registers a new user.

  `opts[:role]` lets trusted callers (e.g. seeds) assign a privileged role;
  it defaults to `"user"` and is never taken from end-user input.
  """
  def register_user(attrs, opts \\ []) do
    role = Keyword.get(opts, :role, "user")

    %User{role: role}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc "Returns an empty registration changeset for forms."
  def change_user_registration(%User{} = user \\ %User{}, attrs \\ %{}) do
    User.registration_changeset(user, attrs, hash_password: false)
  end

  @doc """
  Idempotently ensures a user exists (used by seeds). Returns `{:ok, user}`.
  """
  def ensure_user(%{username: username} = attrs, opts \\ []) do
    case get_user_by_username(username) do
      nil -> register_user(attrs, opts)
      %User{} = user -> {:ok, user}
    end
  end
end
