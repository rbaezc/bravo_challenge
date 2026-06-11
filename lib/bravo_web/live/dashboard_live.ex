defmodule BravoWeb.DashboardLive do
  use BravoWeb, :live_view
  require Logger

  import BravoWeb.Dashboard.ViewHelpers

  alias Bravo.CreditRequests
  alias Bravo.Domain.Rules, as: DomainRules
  alias Bravo.Workflow
  alias BravoWeb.Dashboard.{Components, Modals}

  @page_size 6

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(Bravo.PubSub, "credit_requests")

    filters = %{"country" => "", "status" => "", "start_date" => "", "end_date" => ""}
    result = fetch_page(filters, 1)

    form = %{
      "country" => "ES",
      "full_name" => "",
      "identity_document" => "",
      "requested_amount" => "",
      "monthly_income" => ""
    }

    {:ok,
     socket
     |> assign(
       filters: filters,
       page: result.page,
       total: result.total,
       total_pages: result.total_pages
     )
     |> assign(workflow_statuses: Workflow.status_list())
     |> assign(selected_request: nil, selected_history: [], confirm: nil, show_new_modal: false)
     |> assign(form: to_form(form, as: :credit_request))
     |> stream(:credit_requests, result.entries)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="min-h-screen bg-slate-950 text-slate-100 font-sans pb-24">
        <Components.header current_user={@current_user} />

        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 mt-10 space-y-10">
          <Components.filters filters={@filters} workflow_statuses={@workflow_statuses} />
          <Components.status_banner />
          <Components.requests
            streams={@streams}
            current_user={@current_user}
            page={@page}
            total={@total}
            total_pages={@total_pages}
          />
        </div>

        <Modals.detail_modal
          selected_request={@selected_request}
          selected_history={@selected_history}
          current_user={@current_user}
        />
        <Modals.new_request_modal show={@show_new_modal} form={@form} />
        <Components.confirm_modal confirm={@confirm} />
      </div>
    </Layouts.app>
    """
  end

  # --- Listing / pagination ---

  defp reload(socket, page \\ nil) do
    result = fetch_page(socket.assigns.filters, page || socket.assigns.page)

    socket
    |> assign(page: result.page, total: result.total, total_pages: result.total_pages)
    |> stream(:credit_requests, result.entries, reset: true)
  end

  defp fetch_page(filters, page) do
    filters
    |> Map.merge(%{"page" => page, "page_size" => @page_size})
    |> CreditRequests.paginate_credit_requests()
  end

  # --- New request modal ---

  @impl true
  def handle_event("open_new_modal", _params, socket),
    do: {:noreply, assign(socket, :show_new_modal, true)}

  @impl true
  def handle_event("close_new_modal", _params, socket),
    do: {:noreply, assign(socket, :show_new_modal, false)}

  @impl true
  def handle_event("validate_new", %{"credit_request" => params}, socket) do
    country = Map.get(params, "country", "ES")
    doc = Map.get(params, "identity_document", "")
    form = to_form(params, as: :credit_request)

    form =
      case doc != "" && DomainRules.validate_document(country, doc) do
        {:error, msg} -> %{form | errors: [identity_document: {msg, []}]}
        _ -> form
      end

    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("save_request", %{"credit_request" => params}, socket) do
    if can_write?(socket.assigns.current_user.role) do
      params
      |> Map.merge(%{
        "status" => "submitted",
        "request_date" => DateTime.to_iso8601(DateTime.utc_now())
      })
      |> CreditRequests.create_credit_request()
      |> case do
        {:ok, _request} ->
          {:noreply,
           socket
           |> put_flash(:info, "Solicitud creada con éxito y enviada a evaluación.")
           |> assign(:show_new_modal, false)
           |> reload(1)}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply, assign(socket, :form, to_form(changeset))}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Error: #{inspect(reason)}")}
      end
    else
      {:noreply, put_flash(socket, :error, "No tienes permisos para crear solicitudes.")}
    end
  end

  # --- Filters / pagination ---

  @impl true
  def handle_event("filter", params, socket) do
    filters = Map.take(params, ~w(country status start_date end_date))
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

  # --- Detail modal ---

  @impl true
  def handle_event("view_details", %{"id" => id}, socket) do
    {:noreply,
     socket
     |> assign(:selected_request, CreditRequests.get_credit_request!(id))
     |> assign(:selected_history, CreditRequests.list_status_history(id))}
  end

  @impl true
  def handle_event("close_details", _params, socket) do
    {:noreply, assign(socket, selected_request: nil, selected_history: [])}
  end

  # --- Decision (confirm) ---

  @impl true
  def handle_event("ask_confirm", %{"id" => id, "to" => to, "label" => label}, socket) do
    if can_decide?(socket.assigns.current_user.role) do
      {:noreply, assign(socket, :confirm, %{id: id, to: to, label: label})}
    else
      {:noreply, put_flash(socket, :error, "No tienes permisos para esta acción.")}
    end
  end

  @impl true
  def handle_event("cancel_confirm", _params, socket),
    do: {:noreply, assign(socket, :confirm, nil)}

  @impl true
  def handle_event(
        "confirm_transition",
        _params,
        %{assigns: %{confirm: %{id: id, to: to}}} = socket
      ) do
    decide(assign(socket, :confirm, nil), id, to)
  end

  def handle_event("confirm_transition", _params, socket),
    do: {:noreply, assign(socket, :confirm, nil)}

  # Applies a manual transition; the changeset rejects illegal ones server-side.
  defp decide(socket, id, status) do
    if can_decide?(socket.assigns.current_user.role) do
      case CreditRequests.update_credit_request(id, %{status: status}) do
        {:ok, request} ->
          {:noreply,
           socket
           |> refresh_selected(id, request)
           |> reload()
           |> put_flash(:info, "Estado actualizado a #{status_label(status)}.")}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Transición de estado no permitida.")}
      end
    else
      {:noreply, put_flash(socket, :error, "No tienes permisos para esta acción.")}
    end
  end

  # --- Real-time (PubSub) ---

  @impl true
  def handle_info({:credit_request_status_changed, %{id: id, new_status: status}}, socket) do
    request = CreditRequests.get_credit_request!(id)

    {:noreply,
     socket
     |> refresh_selected(id, request)
     |> reload()
     |> put_flash(
       :info,
       "La solicitud de #{request.full_name} cambió de estado a #{status_label(status)}."
     )}
  end

  @impl true
  def handle_info({:credit_request_updated, id}, socket) do
    request = CreditRequests.get_credit_request!(id)
    {:noreply, socket |> refresh_selected(id, request) |> reload()}
  end

  # Keeps the open detail modal in sync when its request changes.
  defp refresh_selected(socket, id, request) do
    if socket.assigns.selected_request && socket.assigns.selected_request.id == id do
      socket
      |> assign(:selected_request, request)
      |> assign(:selected_history, CreditRequests.list_status_history(id))
    else
      socket
    end
  end
end
