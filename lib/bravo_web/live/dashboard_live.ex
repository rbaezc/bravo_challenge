defmodule BravoWeb.DashboardLive do
  use BravoWeb, :live_view
  require Logger

  alias Bravo.CreditRequests
  alias Bravo.Domain.Rules, as: DomainRules
  alias Bravo.Workflow
  alias BravoWeb.Auth.Authorization

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to real-time status updates broadcasted by workers and listener
      Phoenix.PubSub.subscribe(Bravo.PubSub, "credit_requests")
    end

    filters = %{"country" => "", "status" => "", "start_date" => "", "end_date" => ""}
    page_size = 6
    result = fetch_page(filters, 1, page_size)

    form_params = %{
      "country" => "ES",
      "full_name" => "",
      "identity_document" => "",
      "requested_amount" => "",
      "monthly_income" => ""
    }

    {:ok,
     socket
     |> assign(:filters, filters)
     |> assign(:page, result.page)
     |> assign(:page_size, page_size)
     |> assign(:total, result.total)
     |> assign(:total_pages, result.total_pages)
     |> assign(:workflow_statuses, Workflow.status_list())
     |> assign(:selected_request, nil)
     |> assign(:selected_history, [])
     |> assign(:confirm, nil)
     |> assign(:show_new_modal, false)
     |> assign(:form, to_form(form_params, as: :credit_request))
     |> stream(:credit_requests, result.entries)}
  end

  # Loads a page of results with the current filters and resets the stream.
  defp reload(socket, page \\ nil) do
    page = page || socket.assigns.page
    result = fetch_page(socket.assigns.filters, page, socket.assigns.page_size)

    socket
    |> assign(:page, result.page)
    |> assign(:total, result.total)
    |> assign(:total_pages, result.total_pages)
    |> stream(:credit_requests, result.entries, reset: true)
  end

  defp fetch_page(filters, page, page_size) do
    filters
    |> Map.put("page", page)
    |> Map.put("page_size", page_size)
    |> CreditRequests.paginate_credit_requests()
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="min-h-screen bg-slate-950 text-slate-100 font-sans pb-24">
        <!-- Header -->
        <div class="bg-gradient-to-r from-violet-950 via-slate-900 to-indigo-950 py-10 px-8 border-b border-indigo-900/40 shadow-2xl relative overflow-hidden">
          <div class="absolute inset-0 bg-[linear-gradient(to_right,#1e1b4b_1px,transparent_1px),linear-gradient(to_bottom,#1e1b4b_1px,transparent_1px)] bg-[size:4rem_4rem] [mask-image:radial-gradient(ellipse_60%_50%_at_50%_0%,#000_70%,transparent_100%)] opacity-30">
          </div>
          <div class="max-w-7xl mx-auto flex flex-col md:flex-row justify-between items-center gap-6 relative z-10">
            <div class="text-center md:text-left">
              <div class="flex items-center justify-center md:justify-start gap-4">
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
                class="flex items-center gap-2 px-6 py-3.5 bg-gradient-to-r from-violet-600 to-indigo-600 hover:from-violet-500 hover:to-indigo-500 text-white font-bold rounded-xl shadow-lg shadow-indigo-500/20 hover:shadow-indigo-500/40 transition-all transform hover:-translate-y-0.5 duration-300 cursor-pointer"
              >
                <.icon name="hero-plus-circle" class="w-6 h-6" /> Nueva Solicitud
              </button>
            </div>
          </div>
        </div>

        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 mt-10 space-y-10">
          
    <!-- Filters -->
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
                <select
                  name="country"
                  class="w-full bg-slate-950 border border-slate-800 rounded-xl px-4 py-3 text-slate-100 focus:outline-none focus:border-indigo-500 transition-colors cursor-pointer"
                >
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
                <select
                  name="status"
                  class="w-full bg-slate-950 border border-slate-800 rounded-xl px-4 py-3 text-slate-100 focus:outline-none focus:border-indigo-500 transition-colors cursor-pointer"
                >
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
                <input
                  type="date"
                  name="start_date"
                  value={@filters["start_date"]}
                  class="w-full bg-slate-950 border border-slate-800 rounded-xl px-4 py-3 text-slate-100 focus:outline-none focus:border-indigo-500 transition-colors cursor-pointer"
                />
              </div>

              <div class="flex flex-col justify-end">
                <div class="grid grid-cols-1 gap-2">
                  <button
                    type="button"
                    phx-click="clear_filters"
                    class="py-3 bg-slate-800 hover:bg-slate-700 text-slate-200 font-bold rounded-xl transition-all duration-200 cursor-pointer"
                  >
                    Restablecer Filtros
                  </button>
                </div>
              </div>
            </form>
          </div>
          
    <!-- Status banner -->
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
          
    <!-- Credit request cards -->
          <div class="space-y-6">
            <h2 class="text-2xl font-bold text-slate-100">Solicitudes de Crédito</h2>

            <div
              id="credit_requests-list"
              phx-update="stream"
              class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8"
            >
              <!-- Empty state (needs a unique id inside the stream) -->
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
              
    <!-- Request card -->
              <div
                :for={{dom_id, req} <- @streams.credit_requests}
                id={dom_id}
                class="bg-slate-900/50 backdrop-blur-md rounded-2xl border border-slate-800/80 p-6 flex flex-col justify-between gap-6 hover:scale-[1.02] hover:shadow-indigo-500/5 hover:border-indigo-500/30 transition-all duration-300 shadow-xl"
              >
                <!-- Card Header -->
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
                
    <!-- Card body -->
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
                
    <!-- Card footer / actions -->
                <div class="flex items-center justify-between gap-3 pt-2 border-t border-slate-800/40">
                  <button
                    phx-click="view_details"
                    phx-value-id={req.id}
                    class="flex items-center gap-1.5 px-4 py-2 bg-slate-800 hover:bg-slate-700 text-indigo-300 font-semibold rounded-xl text-xs transition-all cursor-pointer"
                  >
                    <.icon name="hero-eye" class="w-4 h-4" /> Detalles
                  </button>

                  <div class="flex gap-2">
                    <%!-- Manual transitions are derived from the data-driven workflow --%>
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
            
    <!-- Pagination -->
            <div :if={@total_pages > 1} class="flex items-center justify-between gap-4 pt-2">
              <p class="text-sm text-slate-500">
                Página {@page} de {@total_pages} ({@total} solicitudes)
              </p>
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
        </div>
        
    <!-- Detail modal -->
        <%= if @selected_request do %>
          <div
            class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/85 backdrop-blur-md"
            id="detail-modal"
          >
            <div class="bg-slate-900 border border-slate-800 w-full max-w-2xl rounded-2xl shadow-2xl overflow-hidden animate-in fade-in zoom-in duration-300">
              <div class="bg-gradient-to-r from-violet-900 to-indigo-900 p-6 text-white flex justify-between items-center">
                <div>
                  <h3 class="text-2xl font-bold">Detalle de la Solicitud</h3>
                  <p class="text-xs text-indigo-200/80 font-mono mt-1">ID: {@selected_request.id}</p>
                </div>
                <button
                  phx-click="close_details"
                  class="p-2 hover:bg-white/10 rounded-lg transition-all cursor-pointer"
                >
                  <.icon name="hero-x-mark" class="w-6 h-6" />
                </button>
              </div>

              <div class="p-8 space-y-8">
                <!-- Request details grid -->
                <div class="grid grid-cols-2 gap-8 border-b border-slate-800/60 pb-8">
                  <div>
                    <span class="block text-xs text-slate-500 font-bold uppercase tracking-widest mb-1">
                      Solicitante
                    </span>
                    <span class="text-lg font-bold text-slate-100">
                      {@selected_request.full_name}
                    </span>
                  </div>
                  <div>
                    <span class="block text-xs text-slate-500 font-bold uppercase tracking-widest mb-1">
                      País
                    </span>
                    <span class="text-lg font-bold text-slate-100">{@selected_request.country}</span>
                  </div>
                  <div>
                    <span class="block text-xs text-slate-500 font-bold uppercase tracking-widest mb-1">
                      Documento Identidad
                    </span>
                    <span class="text-base font-bold text-slate-300 font-mono">
                      {@selected_request.identity_document}
                    </span>
                  </div>
                  <div>
                    <span class="block text-xs text-slate-500 font-bold uppercase tracking-widest mb-1">
                      Estado Actual
                    </span>
                    <span class={[
                      "inline-block px-3 py-1 rounded-full text-xs font-bold border capitalize tracking-wider mt-1",
                      status_badge_class(@selected_request.status)
                    ]}>
                      {status_label(@selected_request.status)}
                    </span>
                  </div>
                  <div>
                    <span class="block text-xs text-slate-500 font-bold uppercase tracking-widest mb-1">
                      Monto Solicitado
                    </span>
                    <span class="text-2xl font-black text-indigo-400">
                      {to_currency(@selected_request.requested_amount)}
                    </span>
                  </div>
                  <div>
                    <span class="block text-xs text-slate-500 font-bold uppercase tracking-widest mb-1">
                      Ingreso Mensual
                    </span>
                    <span class="text-2xl font-black text-slate-300">
                      {to_currency(@selected_request.monthly_income)}
                    </span>
                  </div>
                </div>
                
    <!-- Banking details obtained from provider -->
                <div class="space-y-4">
                  <h4 class="text-sm font-bold text-indigo-400 uppercase tracking-wider">
                    Información del Proveedor Bancario
                  </h4>

                  <%= if @selected_request.bank_info do %>
                    <div class="bg-slate-950 rounded-2xl p-6 border border-slate-800 space-y-4 font-mono text-sm text-slate-300">
                      <div class="flex justify-between border-b border-slate-800/40 pb-2">
                        <span class="text-slate-500">Proveedor:</span>
                        <span class="font-bold text-slate-200">
                          {Map.get(@selected_request.bank_info, "provider") ||
                            Map.get(@selected_request.bank_info, :provider)}
                        </span>
                      </div>
                      <div class="flex justify-between border-b border-slate-800/40 pb-2">
                        <span class="text-slate-500">Banco Receptor:</span>
                        <span class="font-bold text-slate-200">
                          {Map.get(@selected_request.bank_info, "bank_name") ||
                            Map.get(@selected_request.bank_info, :bank_name)}
                        </span>
                      </div>

                      <%= if Map.get(@selected_request.bank_info, "account_iban") || Map.get(@selected_request.bank_info, :account_iban) do %>
                        <div class="flex justify-between border-b border-slate-800/40 pb-2">
                          <span class="text-slate-500">IBAN:</span>
                          <span class="font-bold text-indigo-400">
                            {mask_string(
                              Map.get(@selected_request.bank_info, "account_iban") ||
                                Map.get(@selected_request.bank_info, :account_iban),
                              4
                            )}
                          </span>
                        </div>
                      <% end %>

                      <%= if Map.get(@selected_request.bank_info, "account_clabe") || Map.get(@selected_request.bank_info, :account_clabe) do %>
                        <div class="flex justify-between border-b border-slate-800/40 pb-2">
                          <span class="text-slate-500">CLABE:</span>
                          <span class="font-bold text-indigo-400">
                            {mask_string(
                              Map.get(@selected_request.bank_info, "account_clabe") ||
                                Map.get(@selected_request.bank_info, :account_clabe),
                              4
                            )}
                          </span>
                        </div>
                      <% end %>

                      <div class="flex justify-between">
                        <span class="text-slate-500">Estado de Validación:</span>
                        <span class="px-2.5 py-0.5 rounded bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 text-xs font-bold uppercase">
                          {Map.get(@selected_request.bank_info, "validation_status") ||
                            Map.get(@selected_request.bank_info, :validation_status)}
                        </span>
                      </div>
                    </div>
                  <% else %>
                    <div class="bg-slate-950 rounded-2xl p-6 border border-slate-800 text-center text-slate-500 text-sm">
                      La información bancaria está siendo consultada y evaluada en segundo plano.
                    </div>
                  <% end %>
                </div>
                
    <!-- Status history (audit trail) -->
                <div class="space-y-4">
                  <h4 class="text-sm font-bold text-indigo-400 uppercase tracking-wider">
                    Historial de Estados
                  </h4>

                  <ol class="relative border-l border-slate-800 ml-3 space-y-5">
                    <li :for={entry <- @selected_history} class="ml-6">
                      <span class="absolute -left-[7px] flex items-center justify-center w-3.5 h-3.5 rounded-full bg-indigo-500 ring-4 ring-slate-900">
                      </span>
                      <div class="flex items-center justify-between gap-3 flex-wrap">
                        <p class="text-sm text-slate-200">
                          <%= if entry.old_status do %>
                            <span class="text-slate-500">{status_label(entry.old_status)}</span>
                            <.icon name="hero-arrow-right" class="w-3 h-3 mx-1 text-slate-600" />
                          <% end %>
                          <span class="font-bold">{status_label(entry.new_status)}</span>
                        </p>
                        <span class="text-xs text-slate-500 font-mono">
                          {format_datetime(entry.changed_at)}
                        </span>
                      </div>
                    </li>
                  </ol>

                  <p :if={@selected_history == []} class="text-sm text-slate-500">
                    Sin cambios de estado registrados.
                  </p>
                </div>
                
    <!-- Decision actions (manual transitions, role-gated) -->
                <div
                  :if={card_actions(@current_user.role, @selected_request) != []}
                  class="pt-6 border-t border-slate-800 flex items-center justify-end gap-3 flex-wrap"
                >
                  <span class="text-sm font-bold text-indigo-400 uppercase tracking-wider mr-auto">
                    Decisión
                  </span>
                  <button
                    :for={t <- card_actions(@current_user.role, @selected_request)}
                    phx-click="ask_confirm"
                    phx-value-id={@selected_request.id}
                    phx-value-to={t.to}
                    phx-value-label={t.label}
                    class={[
                      "flex items-center gap-1.5 px-5 py-2.5 rounded-xl text-sm font-bold transition-all cursor-pointer border",
                      status_badge_class(t.to)
                    ]}
                  >
                    {t.label}
                  </button>
                </div>
              </div>
            </div>
          </div>
        <% end %>
        
    <!-- New request modal -->
        <%= if @show_new_modal do %>
          <div
            class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/85 backdrop-blur-md"
            id="new-modal"
          >
            <div class="bg-slate-900 border border-slate-800 w-full max-w-lg rounded-2xl shadow-2xl overflow-hidden animate-in fade-in zoom-in duration-300">
              <div class="bg-gradient-to-r from-violet-900 to-indigo-900 p-6 text-white flex justify-between items-center">
                <h3 class="text-xl font-bold">Nueva Solicitud de Crédito</h3>
                <button
                  phx-click="close_new_modal"
                  class="p-2 hover:bg-white/10 rounded-lg transition-all cursor-pointer"
                >
                  <.icon name="hero-x-mark" class="w-6 h-6" />
                </button>
              </div>

              <.form
                for={@form}
                id="credit-request-form"
                phx-submit="save_request"
                phx-change="validate_new"
                class="p-8 space-y-6"
              >
                <div>
                  <label class="block text-xs font-bold text-slate-400 uppercase tracking-widest mb-2">
                    País de Residencia
                  </label>
                  <select
                    name="credit_request[country]"
                    class="w-full select select-bordered h-12 bg-slate-950 border-slate-800 text-slate-100 rounded-xl px-4 cursor-pointer"
                  >
                    <option value="ES" selected={@form[:country].value == "ES"}>España (ES)</option>
                    <option value="MX" selected={@form[:country].value == "MX"}>México (MX)</option>
                    <option value="CO" selected={@form[:country].value == "CO"}>Colombia (CO)</option>
                  </select>
                </div>

                <div class="space-y-2">
                  <.input
                    field={@form[:full_name]}
                    label="Nombre Completo"
                    placeholder="Ej. Juan Pérez"
                    required
                    class="w-full input input-bordered h-12 bg-slate-950 border-slate-800 focus:border-indigo-500 text-slate-100 rounded-xl px-4"
                  />
                </div>

                <div class="space-y-2">
                  <.input
                    field={@form[:identity_document]}
                    label={document_label(@form[:country].value)}
                    placeholder={document_placeholder(@form[:country].value)}
                    required
                    class="w-full input input-bordered h-12 bg-slate-950 border-slate-800 focus:border-indigo-500 text-slate-100 rounded-xl px-4 font-mono"
                  />
                </div>

                <div class="grid grid-cols-2 gap-4">
                  <div class="space-y-2">
                    <.input
                      field={@form[:requested_amount]}
                      type="number"
                      step="0.01"
                      label="Monto Solicitado (€ / $)"
                      placeholder="Ej. 3000.00"
                      required
                      class="w-full input input-bordered h-12 bg-slate-950 border-slate-800 focus:border-indigo-500 text-slate-100 rounded-xl px-4"
                    />
                  </div>
                  <div class="space-y-2">
                    <.input
                      field={@form[:monthly_income]}
                      type="number"
                      step="0.01"
                      label="Ingreso Mensual (€ / $)"
                      placeholder="Ej. 1500.00"
                      required
                      class="w-full input input-bordered h-12 bg-slate-950 border-slate-800 focus:border-indigo-500 text-slate-100 rounded-xl px-4"
                    />
                  </div>
                </div>

                <div class="pt-6 flex gap-4">
                  <button
                    type="button"
                    phx-click="close_new_modal"
                    class="flex-1 py-3.5 bg-slate-800 hover:bg-slate-700 text-slate-300 font-bold rounded-xl transition-all cursor-pointer"
                  >
                    Cancelar
                  </button>
                  <button
                    type="submit"
                    class="flex-1 py-3.5 bg-gradient-to-r from-violet-600 to-indigo-600 hover:from-violet-500 hover:to-indigo-500 text-white font-bold rounded-xl shadow-lg transition-all cursor-pointer"
                  >
                    Crear Solicitud
                  </button>
                </div>
              </.form>
            </div>
          </div>
        <% end %>
        
    <!-- Confirmation modal (replaces the native confirm dialog) -->
        <%= if @confirm do %>
          <div id="confirm-modal" class="fixed inset-0 z-[60] flex items-center justify-center p-4">
            <div
              class="absolute inset-0 bg-slate-950/80 backdrop-blur-sm"
              phx-click="cancel_confirm"
            />
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
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  # Role helpers (shared policy with the API).
  defp can_write?(role), do: Authorization.can?(role, :write)
  defp can_decide?(role), do: Authorization.can?(role, :decide)

  # Manual transitions a user may trigger for a given request (data-driven).
  defp card_actions(role, req) do
    if can_decide?(role), do: Workflow.manual_transitions(req.country, req.status), else: []
  end

  # --- Country presentation ---
  defp country_label("ES"), do: "ES"
  defp country_label("MX"), do: "MX"
  defp country_label("CO"), do: "CO"
  defp country_label(country), do: country

  defp country_badge_class("ES"), do: "bg-red-500/10 text-red-400 border-red-500/20"
  defp country_badge_class("MX"), do: "bg-emerald-500/10 text-emerald-400 border-emerald-500/20"
  defp country_badge_class("CO"), do: "bg-amber-500/10 text-amber-400 border-amber-500/20"
  defp country_badge_class(_), do: "bg-slate-500/10 text-slate-400 border-slate-500/20"

  defp document_label("ES"), do: "DNI Español"
  defp document_label("CO"), do: "Cédula de Ciudadanía (CC)"
  defp document_label(_), do: "CURP Mexicano"

  defp document_placeholder("ES"), do: "Ej. 12345678Z"
  defp document_placeholder("CO"), do: "Ej. 1012345678"
  defp document_placeholder(_), do: "Ej. ABCDE123456HMJABC12"

  # --- Status presentation (data-driven from Bravo.Workflow) ---

  defp status_label(nil), do: "-"

  defp status_label(key) do
    case Workflow.status_map()[key] do
      nil -> key
      status -> status.label
    end
  end

  defp status_badge_class(key) do
    color =
      case Workflow.status_map()[key] do
        nil -> "slate"
        status -> status.color
      end

    color_classes(color)
  end

  # Literal Tailwind class strings (so the JIT compiler keeps them). Unknown
  # colors fall back to slate.
  defp color_classes("blue"), do: "bg-blue-500/10 text-blue-400 border-blue-500/20"
  defp color_classes("amber"), do: "bg-amber-500/10 text-amber-400 border-amber-500/20"
  defp color_classes("emerald"), do: "bg-emerald-500/10 text-emerald-400 border-emerald-500/20"
  defp color_classes("rose"), do: "bg-rose-500/10 text-rose-400 border-rose-500/20"
  defp color_classes("cyan"), do: "bg-cyan-500/10 text-cyan-400 border-cyan-500/20"
  defp color_classes("violet"), do: "bg-violet-500/10 text-violet-400 border-violet-500/20"
  defp color_classes(_), do: "bg-slate-500/10 text-slate-400 border-slate-500/20"

  defp format_datetime(nil), do: "-"

  defp format_datetime(%DateTime{} = dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S UTC")
  end

  defp format_datetime(%NaiveDateTime{} = dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S UTC")
  end

  defp format_datetime(other), do: to_string(other)

  # Format currency helper
  defp to_currency(nil), do: "$0.00"

  defp to_currency(val) do
    case Decimal.cast(val) do
      {:ok, decimal} ->
        "$" <> (decimal |> Decimal.round(2) |> Decimal.to_string())

      _ ->
        "$0.00"
    end
  end

  defp mask_string(nil, _), do: nil

  defp mask_string(str, visible_suffix_len) do
    len = String.length(str)

    if len > visible_suffix_len do
      prefix = String.duplicate("*", len - visible_suffix_len)
      suffix = String.slice(str, -visible_suffix_len..-1)
      prefix <> suffix
    else
      str
    end
  end

  # --- Handlers ---

  @impl true
  def handle_event("open_new_modal", _params, socket) do
    {:noreply, assign(socket, :show_new_modal, true)}
  end

  @impl true
  def handle_event("close_new_modal", _params, socket) do
    {:noreply, assign(socket, :show_new_modal, false)}
  end

  @impl true
  def handle_event("validate_new", %{"credit_request" => params}, socket) do
    # Validate the document format dynamically depending on selected country
    country = Map.get(params, "country", "ES")
    doc = Map.get(params, "identity_document", "")

    # We map changes to a transient form so errors can show up
    form = to_form(params, as: :credit_request)

    # We can inject validation errors dynamically
    form =
      if doc != "" do
        case DomainRules.validate_document(country, doc) do
          :ok -> form
          {:error, msg} -> %{form | errors: [identity_document: {msg, []}]}
        end
      else
        form
      end

    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("save_request", %{"credit_request" => params}, socket) do
    cond do
      not can_write?(socket.assigns.current_user.role) ->
        {:noreply, put_flash(socket, :error, "No tienes permisos para crear solicitudes.")}

      true ->
        # Prepare params with defaults
        full_params =
          params
          |> Map.put("status", "submitted")
          |> Map.put("request_date", DateTime.utc_now() |> DateTime.to_iso8601())

        case CreditRequests.create_credit_request(full_params) do
          {:ok, _request} ->
            {:noreply,
             socket
             |> put_flash(:info, "Solicitud creada con éxito y enviada a evaluación.")
             |> assign(:show_new_modal, false)
             # Jump to the first page so the new request is visible.
             |> reload(1)}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, :form, to_form(changeset))}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, "Error: #{inspect(reason)}")}
        end
    end
  end

  @impl true
  def handle_event("filter", params, socket) do
    filters = %{
      "country" => Map.get(params, "country", ""),
      "status" => Map.get(params, "status", ""),
      "start_date" => Map.get(params, "start_date", ""),
      "end_date" => Map.get(params, "end_date", "")
    }

    # New filters reset to the first page.
    {:noreply, socket |> assign(:filters, filters) |> reload(1)}
  end

  @impl true
  def handle_event("clear_filters", _params, socket) do
    filters = %{"country" => "", "status" => "", "start_date" => "", "end_date" => ""}
    {:noreply, socket |> assign(:filters, filters) |> reload(1)}
  end

  @impl true
  def handle_event("paginate", %{"page" => page}, socket) do
    {:noreply, reload(socket, String.to_integer(page))}
  end

  @impl true
  def handle_event("view_details", %{"id" => id}, socket) do
    # Fetch full credit request detail and its status audit trail
    request = CreditRequests.get_credit_request!(id)

    {:noreply,
     socket
     |> assign(:selected_request, request)
     |> assign(:selected_history, CreditRequests.list_status_history(id))}
  end

  @impl true
  def handle_event("close_details", _params, socket) do
    {:noreply,
     socket
     |> assign(:selected_request, nil)
     |> assign(:selected_history, [])}
  end

  @impl true
  def handle_event("ask_confirm", %{"id" => id, "to" => to, "label" => label}, socket) do
    if can_decide?(socket.assigns.current_user.role) do
      {:noreply, assign(socket, :confirm, %{id: id, to: to, label: label})}
    else
      {:noreply, put_flash(socket, :error, "No tienes permisos para esta acción.")}
    end
  end

  @impl true
  def handle_event("cancel_confirm", _params, socket) do
    {:noreply, assign(socket, :confirm, nil)}
  end

  @impl true
  def handle_event(
        "confirm_transition",
        _params,
        %{assigns: %{confirm: %{id: id, to: to}}} = socket
      ) do
    decide(assign(socket, :confirm, nil), id, to)
  end

  def handle_event("confirm_transition", _params, socket) do
    {:noreply, assign(socket, :confirm, nil)}
  end

  # Applies a manual transition, enforcing the role policy and the workflow
  # rules server-side (the changeset rejects illegal transitions).
  defp decide(socket, id, status) do
    if can_decide?(socket.assigns.current_user.role) do
      case CreditRequests.update_credit_request(id, %{status: status}) do
        {:ok, request} ->
          {:noreply,
           socket
           |> maybe_refresh_selected(id, request)
           |> reload()
           |> put_flash(:info, "Estado actualizado a #{status_label(status)}.")}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Transición de estado no permitida.")}
      end
    else
      {:noreply, put_flash(socket, :error, "No tienes permisos para esta acción.")}
    end
  end

  # --- PubSub Event Handlers for Real-Time ---

  @impl true
  def handle_info({:credit_request_status_changed, %{id: id, new_status: new_status}}, socket) do
    Logger.info("PubSub: request #{id} status changed to #{new_status}")

    request = CreditRequests.get_credit_request!(id)

    {:noreply,
     socket
     |> maybe_refresh_selected(id, request)
     # Reload the current page so the change is reflected without cross-page artifacts.
     |> reload()
     |> put_flash(
       :info,
       "La solicitud de #{request.full_name} cambió de estado a #{status_label(new_status)}."
     )}
  end

  @impl true
  def handle_info({:credit_request_updated, id}, socket) do
    Logger.info("PubSub: request #{id} was updated")
    request = CreditRequests.get_credit_request!(id)

    {:noreply, socket |> maybe_refresh_selected(id, request) |> reload()}
  end

  # Keeps the open detail modal (request + history) in sync with live updates.
  defp maybe_refresh_selected(socket, id, request) do
    if socket.assigns.selected_request && socket.assigns.selected_request.id == id do
      socket
      |> assign(:selected_request, request)
      |> assign(:selected_history, CreditRequests.list_status_history(id))
    else
      socket
    end
  end
end
