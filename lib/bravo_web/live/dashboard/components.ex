defmodule BravoWeb.Dashboard.Components do
  @moduledoc "Function components for the credit dashboard page (header, filters, cards)."
  use BravoWeb, :html

  import BravoWeb.Dashboard.ViewHelpers

  attr :current_user, :map, required: true

  def header(assigns) do
    ~H"""
    <div class="bg-gradient-to-r from-violet-950 via-slate-900 to-indigo-950 py-10 px-8 border-b border-indigo-900/40 shadow-2xl relative overflow-hidden">
      <div class="absolute inset-0 bg-[linear-gradient(to_right,#1e1b4b_1px,transparent_1px),linear-gradient(to_bottom,#1e1b4b_1px,transparent_1px)] bg-[size:4rem_4rem] [mask-image:radial-gradient(ellipse_60%_50%_at_50%_0%,#000_70%,transparent_100%)] opacity-30">
      </div>
      <div class="max-w-7xl mx-auto flex flex-col md:flex-row justify-between items-center gap-6 relative z-10">
        <div class="flex items-center gap-4">
          <div class="p-3 bg-indigo-500/10 rounded-2xl border border-indigo-500/25 shadow-inner backdrop-blur-md">
            <.icon name="hero-credit-card" class="w-10 h-10 text-indigo-400" />
          </div>
          <div>
            <h1 class="text-4xl font-extrabold tracking-tight bg-clip-text text-transparent bg-gradient-to-r from-indigo-300 via-indigo-100 to-white">
              Evaluación de Crédito Bravo
            </h1>
            <p class="text-indigo-300/70 text-sm mt-1 font-medium tracking-wide">
              Sistema de análisis de riesgo y gestión de solicitudes multipaís
            </p>
          </div>
        </div>

        <div class="flex items-center gap-4">
          <div class="flex items-center gap-3 px-4 py-2.5 bg-slate-900/60 rounded-xl border border-slate-800/80">
            <div class="w-9 h-9 rounded-full bg-indigo-500/20 border border-indigo-500/30 flex items-center justify-center">
              <.icon name="hero-user" class="w-5 h-5 text-indigo-300" />
            </div>
            <div class="text-left leading-tight">
              <p class="text-sm font-bold text-slate-100">{@current_user.name}</p>
              <p class="text-[10px] uppercase tracking-wider text-indigo-400 font-mono">
                {@current_user.role}
              </p>
            </div>
            <.form for={%{}} action={~p"/logout"} method="delete" class="ml-1">
              <button
                type="submit"
                title="Cerrar sesión"
                class="p-2 text-slate-400 hover:text-rose-400 hover:bg-rose-500/10 rounded-lg transition-all cursor-pointer"
              >
                <.icon name="hero-arrow-right-on-rectangle" class="w-5 h-5" />
              </button>
            </.form>
          </div>

          <button
            :if={can_write?(@current_user.role)}
            phx-click="open_new_modal"
            id="new-request-btn"
            class="flex items-center gap-2 px-6 py-3.5 bg-gradient-to-r from-violet-600 to-indigo-600 hover:from-violet-500 hover:to-indigo-500 text-white font-bold rounded-xl shadow-lg transition-all cursor-pointer"
          >
            <.icon name="hero-plus-circle" class="w-6 h-6" /> Nueva Solicitud
          </button>
        </div>
      </div>
    </div>
    """
  end

  attr :filters, :map, required: true
  attr :workflow_statuses, :list, required: true

  def filters(assigns) do
    ~H"""
    <div class="bg-slate-900/60 backdrop-blur-xl p-8 rounded-2xl border border-slate-800/80 shadow-xl">
      <div class="flex items-center gap-2.5 mb-6 border-b border-slate-800 pb-3">
        <.icon name="hero-funnel" class="w-5 h-5 text-indigo-400" />
        <h2 class="text-base font-bold text-indigo-400 uppercase tracking-wider">
          Filtros de Búsqueda
        </h2>
      </div>

      <form phx-change="filter" class="grid grid-cols-1 md:grid-cols-4 gap-6" id="filters-form">
        <div>
          <label class="block text-xs font-semibold text-slate-400 uppercase tracking-wider mb-2">
            País
          </label>
          <select name="country" class={select_class()}>
            <option value="">Todos los Países</option>
            <option value="ES" selected={@filters["country"] == "ES"}>España (ES)</option>
            <option value="MX" selected={@filters["country"] == "MX"}>México (MX)</option>
            <option value="CO" selected={@filters["country"] == "CO"}>Colombia (CO)</option>
          </select>
        </div>

        <div>
          <label class="block text-xs font-semibold text-slate-400 uppercase tracking-wider mb-2">
            Estado
          </label>
          <select name="status" class={select_class()}>
            <option value="">Todos los Estados</option>
            <option
              :for={s <- @workflow_statuses}
              value={s.key}
              selected={@filters["status"] == s.key}
            >
              {s.label}
            </option>
          </select>
        </div>

        <div>
          <label class="block text-xs font-semibold text-slate-400 uppercase tracking-wider mb-2">
            Fecha Desde
          </label>
          <input type="date" name="start_date" value={@filters["start_date"]} class={select_class()} />
        </div>

        <div class="flex flex-col justify-end">
          <button
            type="button"
            phx-click="clear_filters"
            class="py-3 bg-slate-800 hover:bg-slate-700 text-slate-200 font-bold rounded-xl transition-all cursor-pointer"
          >
            Restablecer Filtros
          </button>
        </div>
      </form>
    </div>
    """
  end

  defp select_class do
    "w-full bg-slate-950 border border-slate-800 rounded-xl px-4 py-3 text-slate-100 focus:outline-none focus:border-indigo-500 transition-colors cursor-pointer"
  end

  def status_banner(assigns) do
    ~H"""
    <div class="flex flex-col sm:flex-row justify-between items-center bg-indigo-950/20 border border-indigo-900/30 rounded-2xl py-4 px-6 gap-4">
      <div class="flex items-center gap-3">
        <span class="relative flex h-3 w-3">
          <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75">
          </span>
          <span class="relative inline-flex rounded-full h-3 w-3 bg-emerald-500"></span>
        </span>
        <p class="text-slate-300 text-sm font-medium">
          Servicio de evaluación de crédito activo. Las actualizaciones de riesgo se procesan automáticamente.
        </p>
      </div>
      <span class="px-3 py-1 bg-slate-900 rounded-full text-xs text-indigo-400 font-mono border border-indigo-900/20">
        Evaluación en Línea
      </span>
    </div>
    """
  end

  attr :streams, :map, required: true
  attr :current_user, :map, required: true
  attr :page, :integer, required: true
  attr :total, :integer, required: true
  attr :total_pages, :integer, required: true

  def requests(assigns) do
    ~H"""
    <div class="space-y-6">
      <h2 class="text-2xl font-bold text-slate-100">Solicitudes de Crédito</h2>

      <div
        id="credit_requests-list"
        phx-update="stream"
        class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8"
      >
        <div
          id="empty-state"
          class="hidden only:block col-span-full bg-slate-900/40 p-16 text-center text-slate-400 rounded-2xl border border-dashed border-slate-800"
        >
          <.icon name="hero-inbox" class="w-16 h-16 text-slate-700 mx-auto mb-4" />
          <h3 class="text-lg font-bold text-slate-300">Sin Solicitudes</h3>
          <p class="text-sm text-slate-500 mt-1 max-w-md mx-auto">
            No se encontraron solicitudes registradas con los filtros seleccionados actualmente.
          </p>
        </div>

        <div
          :for={{dom_id, req} <- @streams.credit_requests}
          id={dom_id}
          class="bg-slate-900/50 backdrop-blur-md rounded-2xl border border-slate-800/80 p-6 flex flex-col justify-between gap-6 hover:border-indigo-500/30 transition-all shadow-xl"
        >
          <div class="flex justify-between items-start gap-4">
            <div class="space-y-1">
              <span class={[
                "px-3 py-1 rounded-md text-xs font-black border tracking-wider",
                country_badge_class(req.country)
              ]}>
                {country_label(req.country)}
              </span>
              <h3 class="text-lg font-bold text-slate-100 pt-2">{req.full_name}</h3>
              <p class="text-xs text-slate-500 font-mono">Doc: {req.identity_document}</p>
            </div>
            <span class={[
              "px-3 py-1 rounded-full text-xs font-extrabold border shadow-inner capitalize tracking-wide",
              status_badge_class(req.status)
            ]}>
              {status_label(req.status)}
            </span>
          </div>

          <div class="grid grid-cols-2 gap-4 bg-slate-950/40 p-4 rounded-xl border border-slate-800/40">
            <div>
              <span class="block text-[10px] text-slate-500 uppercase tracking-widest font-bold">
                Monto Solicitado
              </span>
              <span class="text-xl font-black text-indigo-400">
                {to_currency(req.requested_amount)}
              </span>
            </div>
            <div>
              <span class="block text-[10px] text-slate-500 uppercase tracking-widest font-bold">
                Ingreso Mensual
              </span>
              <span class="text-base font-bold text-slate-300">
                {to_currency(req.monthly_income)}
              </span>
            </div>
          </div>

          <div class="flex items-center justify-between gap-3 pt-2 border-t border-slate-800/40">
            <button
              phx-click="view_details"
              phx-value-id={req.id}
              class="flex items-center gap-1.5 px-4 py-2 bg-slate-800 hover:bg-slate-700 text-indigo-300 font-semibold rounded-xl text-xs transition-all cursor-pointer"
            >
              <.icon name="hero-eye" class="w-4 h-4" /> Detalles
            </button>
            <div class="flex gap-2">
              <button
                :for={t <- card_actions(@current_user.role, req)}
                phx-click="ask_confirm"
                phx-value-id={req.id}
                phx-value-to={t.to}
                phx-value-label={t.label}
                class={[
                  "flex items-center gap-1.5 px-3 py-2 rounded-lg text-xs font-semibold transition-all cursor-pointer border",
                  status_badge_class(t.to)
                ]}
                title={t.label}
              >
                {t.label}
              </button>
            </div>
          </div>
        </div>
      </div>

      <div :if={@total_pages > 1} class="flex items-center justify-between gap-4 pt-2">
        <p class="text-sm text-slate-500">Página {@page} de {@total_pages} ({@total} solicitudes)</p>
        <div class="flex items-center gap-2">
          <button
            phx-click="paginate"
            phx-value-page={@page - 1}
            disabled={@page <= 1}
            class="flex items-center gap-1 px-4 py-2 bg-slate-800 hover:bg-slate-700 text-slate-200 font-semibold rounded-xl text-sm transition-all cursor-pointer disabled:opacity-40 disabled:cursor-not-allowed"
          >
            <.icon name="hero-chevron-left" class="w-4 h-4" /> Anterior
          </button>
          <button
            phx-click="paginate"
            phx-value-page={@page + 1}
            disabled={@page >= @total_pages}
            class="flex items-center gap-1 px-4 py-2 bg-slate-800 hover:bg-slate-700 text-slate-200 font-semibold rounded-xl text-sm transition-all cursor-pointer disabled:opacity-40 disabled:cursor-not-allowed"
          >
            Siguiente <.icon name="hero-chevron-right" class="w-4 h-4" />
          </button>
        </div>
      </div>
    </div>
    """
  end

  attr :confirm, :map, default: nil

  def confirm_modal(assigns) do
    ~H"""
    <div
      :if={@confirm}
      id="confirm-modal"
      class="fixed inset-0 z-[60] flex items-center justify-center p-4"
    >
      <div class="absolute inset-0 bg-slate-950/80 backdrop-blur-sm" phx-click="cancel_confirm" />
      <div class="relative w-full max-w-md bg-slate-900 border border-slate-800 rounded-2xl shadow-2xl overflow-hidden">
        <div class="flex items-center gap-3 px-6 py-4 border-b border-slate-800">
          <.icon name="hero-exclamation-circle" class="w-6 h-6 text-indigo-400" />
          <h3 class="text-base font-bold text-slate-100">Confirmar acción</h3>
        </div>
        <div class="px-6 py-5">
          <p class="text-sm text-slate-300">
            ¿Confirmas la acción <span class="font-bold text-slate-100">{@confirm.label}</span>
            para esta solicitud?
          </p>
        </div>
        <div class="px-6 py-4 border-t border-slate-800 flex justify-end gap-3">
          <button
            type="button"
            phx-click="cancel_confirm"
            class="px-5 py-2 rounded-xl text-sm font-semibold bg-slate-800 hover:bg-slate-700 text-slate-200 cursor-pointer transition-colors"
          >
            Cancelar
          </button>
          <button
            type="button"
            phx-click="confirm_transition"
            class="px-5 py-2 rounded-xl text-sm font-bold bg-indigo-600 hover:bg-indigo-500 text-white cursor-pointer transition-colors"
          >
            Confirmar
          </button>
        </div>
      </div>
    </div>
    """
  end
end
