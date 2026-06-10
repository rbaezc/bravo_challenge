defmodule BravoWeb.Auth.Token do
  @moduledoc """
  Module to handle JWT generation and verification using Joken.
  """
  use Joken.Config

  @impl true
  def token_config do
    # 2 hours expiration
    default_claims(default_exp: 2 * 60 * 60)
  end

  @doc """
  Generates a JWT token for a given user ID and role.
  """
  def generate_token(user_id, role) do
    claims = %{"user_id" => user_id, "role" => role}
    signer = get_signer()

    case generate_and_sign(claims, signer) do
      {:ok, token, _claims} -> {:ok, token}
      error -> error
    end
  end

  @doc """
  Verifies a JWT token and returns the claims.
  """
  def verify_token(token) do
    signer = get_signer()
    verify_and_validate(token, signer)
  end

  # Returns the signer configured with the application secret key
  defp get_signer do
    secret =
      Application.get_env(:bravo, BravoWeb.Endpoint)[:secret_key_base] ||
        "default_auth_secret_key_base_at_least_32_characters_long"

    # Ensure the secret is at least 32 bytes for HS256
    secret_bytes = String.pad_trailing(secret, 32, "0")
    Joken.Signer.create("HS256", secret_bytes)
  end
end
