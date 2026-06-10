defmodule Bravo.AccountsFixtures do
  @moduledoc """
  Test helpers for creating users via the `Bravo.Accounts` context.
  """

  def valid_user_password, do: "hello world!"

  def unique_username, do: "user#{System.unique_integer([:positive])}"

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      username: unique_username(),
      name: "Test User",
      password: valid_user_password()
    })
  end

  def user_fixture(attrs \\ %{}) do
    role = Map.get(attrs, :role, "user")

    {:ok, user} =
      attrs
      |> Map.delete(:role)
      |> valid_user_attributes()
      |> Bravo.Accounts.register_user(role: role)

    user
  end
end
