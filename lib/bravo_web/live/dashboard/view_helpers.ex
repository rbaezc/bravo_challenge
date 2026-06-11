defmodule BravoWeb.Dashboard.ViewHelpers do
  @moduledoc """
  Presentation helpers for the credit dashboard: role checks, labels, Tailwind
  color classes and value formatting. Shared by the LiveView and its components.
  """
  alias Bravo.Workflow
  alias BravoWeb.Auth.Authorization

  def can_write?(role), do: Authorization.can?(role, :write)
  def can_decide?(role), do: Authorization.can?(role, :decide)

  @doc "Manual transitions a user may trigger for a request (data-driven)."
  def card_actions(role, req) do
    if can_decide?(role), do: Workflow.manual_transitions(req.country, req.status), else: []
  end

  def country_label("ES"), do: "ES"
  def country_label("MX"), do: "MX"
  def country_label("CO"), do: "CO"
  def country_label(country), do: country

  def country_badge_class("ES"), do: "bg-red-500/10 text-red-400 border-red-500/20"
  def country_badge_class("MX"), do: "bg-emerald-500/10 text-emerald-400 border-emerald-500/20"
  def country_badge_class("CO"), do: "bg-amber-500/10 text-amber-400 border-amber-500/20"
  def country_badge_class(_), do: "bg-slate-500/10 text-slate-400 border-slate-500/20"

  def document_label("ES"), do: "DNI Español"
  def document_label("CO"), do: "Cédula de Ciudadanía (CC)"
  def document_label(_), do: "CURP Mexicano"

  def document_placeholder("ES"), do: "Ej. 12345678Z"
  def document_placeholder("CO"), do: "Ej. 1012345678"
  def document_placeholder(_), do: "Ej. ABCDE123456HMJABC12"

  def status_label(nil), do: "-"

  def status_label(key) do
    case Workflow.status_map()[key] do
      nil -> key
      status -> status.label
    end
  end

  def status_badge_class(key) do
    color =
      case Workflow.status_map()[key] do
        nil -> "slate"
        status -> status.color
      end

    color_classes(color)
  end

  # Literal Tailwind class strings (so the JIT keeps them); unknown -> slate.
  def color_classes("blue"), do: "bg-blue-500/10 text-blue-400 border-blue-500/20"
  def color_classes("amber"), do: "bg-amber-500/10 text-amber-400 border-amber-500/20"
  def color_classes("emerald"), do: "bg-emerald-500/10 text-emerald-400 border-emerald-500/20"
  def color_classes("rose"), do: "bg-rose-500/10 text-rose-400 border-rose-500/20"
  def color_classes("cyan"), do: "bg-cyan-500/10 text-cyan-400 border-cyan-500/20"
  def color_classes("violet"), do: "bg-violet-500/10 text-violet-400 border-violet-500/20"
  def color_classes(_), do: "bg-slate-500/10 text-slate-400 border-slate-500/20"

  def format_datetime(nil), do: "-"
  def format_datetime(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S UTC")
  def format_datetime(%NaiveDateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S UTC")
  def format_datetime(other), do: to_string(other)

  def to_currency(nil), do: "$0.00"

  def to_currency(val) do
    case Decimal.cast(val) do
      {:ok, decimal} -> "$" <> (decimal |> Decimal.round(2) |> Decimal.to_string())
      _ -> "$0.00"
    end
  end

  def mask_string(nil, _), do: nil

  def mask_string(str, visible) do
    if String.length(str) > visible do
      String.duplicate("*", String.length(str) - visible) <> String.slice(str, -visible..-1)
    else
      str
    end
  end
end
