defmodule Bravo.AccountsTest do
  use Bravo.DataCase, async: true

  import Bravo.AccountsFixtures

  alias Bravo.Accounts
  alias Bravo.Accounts.User

  describe "register_user/2" do
    test "hashes the password and never stores it in plaintext" do
      {:ok, user} =
        Accounts.register_user(valid_user_attributes(username: "alice", password: "supersecret"))

      assert user.username == "alice"
      assert is_binary(user.hashed_password)
      refute user.hashed_password == "supersecret"
      assert is_nil(user.password)
    end

    test "defaults role to user and ignores role from input (no privilege escalation)" do
      {:ok, user} =
        Accounts.register_user(%{
          username: "mallory",
          name: "Mallory",
          password: "supersecret",
          role: "admin"
        })

      assert user.role == "user"
    end

    test "seeds/trusted callers can assign a role explicitly" do
      {:ok, user} =
        Accounts.register_user(valid_user_attributes(username: "boss"), role: "admin")

      assert user.role == "admin"
    end

    test "enforces minimum password length" do
      {:error, changeset} =
        Accounts.register_user(valid_user_attributes(username: "shorty", password: "short"))

      assert %{password: ["should be at least 8 character(s)"]} = errors_on(changeset)
    end

    test "enforces unique username (case-insensitive)" do
      _ = user_fixture(%{username: "dup"})

      {:error, changeset} =
        Accounts.register_user(valid_user_attributes(username: "DUP"))

      assert %{username: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "get_user_by_username_and_password/2" do
    test "returns the user with valid credentials" do
      user = user_fixture(%{username: "carol", password: "supersecret"})
      assert %User{id: id} = Accounts.get_user_by_username_and_password("carol", "supersecret")
      assert id == user.id
    end

    test "is case-insensitive on username" do
      user = user_fixture(%{username: "dave", password: "supersecret"})
      assert %User{id: id} = Accounts.get_user_by_username_and_password("DAVE", "supersecret")
      assert id == user.id
    end

    test "returns nil with wrong password" do
      _ = user_fixture(%{username: "erin", password: "supersecret"})
      refute Accounts.get_user_by_username_and_password("erin", "wrong")
    end

    test "returns nil for unknown user" do
      refute Accounts.get_user_by_username_and_password("nobody", "whatever")
    end
  end
end
