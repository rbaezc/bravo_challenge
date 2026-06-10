defmodule BravoWeb.Auth.SessionHooks do
  @moduledoc """
  LiveView `on_mount` hooks for browser session authentication.

  Assigns `:current_user` from the session and redirects unauthenticated
  visitors to the login page.
  """
  import Phoenix.LiveView
  import Phoenix.Component

  def on_mount(:require_authenticated, _params, session, socket) do
    case session["current_user"] do
      %{} = user ->
        {:cont, assign(socket, :current_user, user)}

      _ ->
        {:halt, redirect(socket, to: "/login")}
    end
  end
end
