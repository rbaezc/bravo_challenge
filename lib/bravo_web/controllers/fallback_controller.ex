defmodule BravoWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use BravoWeb, :controller

  # This clause handles errors returned by Ecto's insert/update/delete.
  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: BravoWeb.ChangesetJSON)
    |> render(:error, changeset: changeset)
  end

  # This clause handles authorization failures (insufficient role).
  def call(conn, {:error, :forbidden}) do
    conn
    |> put_status(:forbidden)
    |> put_view(json: BravoWeb.ErrorJSON)
    |> render(:"403")
  end

  # This clause is an example of how to handle resources that cannot be found.
  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(html: BravoWeb.ErrorHTML, json: BravoWeb.ErrorJSON)
    |> render(:"404")
  end
end
