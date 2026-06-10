defmodule Bravo.Accounts.User do
  @moduledoc """
  User schema for browser auth. The virtual `:password` is hashed with bcrypt into
  `:hashed_password`; both are `redact: true` so they never leak in logs/inspect.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @roles ~w(admin officer user)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users" do
    field :username, :string
    field :name, :string
    field :role, :string, default: "user"

    field :password, :string, virtual: true, redact: true
    field :password_confirmation, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true

    timestamps(type: :utc_datetime)
  end

  @doc "List of valid roles."
  def roles, do: @roles

  @doc """
  Registration changeset. `:role` is not cast from input (anti privilege
  escalation); it comes from the struct (default `"user"`). `opts[:hash_password]`
  (default `true`) can be set to `false` in tests to skip the bcrypt cost.
  """
  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:username, :name, :password, :password_confirmation])
    |> validate_required([:username, :name, :password])
    |> validate_length(:username, min: 3, max: 30)
    |> validate_format(:username, ~r/^[a-zA-Z0-9_]+$/,
      message: "solo puede contener letras, números y guion bajo"
    )
    |> update_change(:username, &String.downcase/1)
    |> validate_length(:name, min: 2, max: 100)
    |> validate_inclusion(:role, @roles)
    |> validate_password()
    |> unsafe_validate_unique(:username, Bravo.Repo)
    |> unique_constraint(:username)
    |> maybe_hash_password(opts)
  end

  defp validate_password(changeset) do
    changeset
    # bcrypt truncates at 72 bytes, so cap the length there.
    |> validate_length(:password, min: 8, max: 72)
    |> validate_confirmation(:password, message: "no coincide con la contraseña")
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
      |> delete_change(:password_confirmation)
    else
      changeset
    end
  end

  @doc """
  Verifies a password against the stored hash in constant time. Runs a dummy
  bcrypt check when the user is `nil` to avoid leaking existence via timing.
  """
  def valid_password?(%__MODULE__{hashed_password: hashed}, password)
      when is_binary(hashed) and is_binary(password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed)
  end

  def valid_password?(_user, _password) do
    Bcrypt.no_user_verify()
    false
  end
end
