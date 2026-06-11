defmodule BravoWeb.Dashboard.Modals do
  @moduledoc "Detail and new-request modals for the credit dashboard."
  use BravoWeb, :html

  import BravoWeb.Dashboard.ViewHelpers

  attr :selected_request, :map, default: nil
  attr :selected_history, :list, default: []
  attr :current_user, :map, required: true

  def detail_modal(assigns) do
    ~H"""
    <div
      :if={@selected_request}
      id="detail-modal"
      class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/85 backdrop-blur-md"
    >
      <div class="bg-slate-900 border border-slate-800 w-full max-w-2xl rounded-2xl shadow-2xl overflow-hidden">
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
          <div class="grid grid-cols-2 gap-8 border-b border-slate-800/60 pb-8">
            <.detail_field label="Solicitante" value={@selected_request.full_name} />
            <.detail_field label="País" value={@selected_request.country} />
            <.detail_field
              label="Documento Identidad"
              value={@selected_request.identity_document}
              mono
            />
            <div>
              <.detail_caption text="Estado Actual" />
              <span class={[
                "inline-block px-3 py-1 rounded-full text-xs font-bold border capitalize tracking-wider mt-1",
                status_badge_class(@selected_request.status)
              ]}>
                {status_label(@selected_request.status)}
              </span>
            </div>
            <.detail_field
              label="Monto Solicitado"
              value={to_currency(@selected_request.requested_amount)}
              big
            />
            <.detail_field
              label="Ingreso Mensual"
              value={to_currency(@selected_request.monthly_income)}
              big
            />
          </div>

          <div class="space-y-4">
            <h4 class="text-sm font-bold text-indigo-400 uppercase tracking-wider">
              Información del Proveedor Bancario
            </h4>
            <.bank_info bank_info={@selected_request.bank_info} />
          </div>

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
                    <span :if={entry.old_status} class="text-slate-500">
                      {status_label(entry.old_status)}
                    </span>
                    <.icon
                      :if={entry.old_status}
                      name="hero-arrow-right"
                      class="w-3 h-3 mx-1 text-slate-600"
                    />
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
                "px-5 py-2.5 rounded-xl text-sm font-bold transition-all cursor-pointer border",
                status_badge_class(t.to)
              ]}
            >
              {t.label}
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :mono, :boolean, default: false
  attr :big, :boolean, default: false

  defp detail_field(assigns) do
    ~H"""
    <div>
      <.detail_caption text={@label} />
      <span class={[
        @big && "text-2xl font-black text-indigo-400",
        !@big && "text-lg font-bold text-slate-100",
        @mono && "font-mono text-slate-300"
      ]}>
        {@value}
      </span>
    </div>
    """
  end

  attr :text, :string, required: true

  defp detail_caption(assigns) do
    ~H"""
    <span class="block text-xs text-slate-500 font-bold uppercase tracking-widest mb-1">{@text}</span>
    """
  end

  attr :bank_info, :map, default: nil

  defp bank_info(%{bank_info: nil} = assigns) do
    ~H"""
    <div class="bg-slate-950 rounded-2xl p-6 border border-slate-800 text-center text-slate-500 text-sm">
      La información bancaria está siendo consultada y evaluada en segundo plano.
    </div>
    """
  end

  defp bank_info(assigns) do
    ~H"""
    <div class="bg-slate-950 rounded-2xl p-6 border border-slate-800 space-y-4 font-mono text-sm text-slate-300">
      <.bank_row label="Proveedor:" value={bank_field(@bank_info, :provider)} />
      <.bank_row label="Banco Receptor:" value={bank_field(@bank_info, :bank_name)} />
      <.bank_row
        :if={bank_field(@bank_info, :account_iban)}
        label="IBAN:"
        value={mask_string(bank_field(@bank_info, :account_iban), 4)}
        accent
      />
      <.bank_row
        :if={bank_field(@bank_info, :account_clabe)}
        label="CLABE:"
        value={mask_string(bank_field(@bank_info, :account_clabe), 4)}
        accent
      />
      <.bank_row
        :if={bank_field(@bank_info, :account_number)}
        label="Cuenta:"
        value={mask_string(bank_field(@bank_info, :account_number), 4)}
        accent
      />
      <div class="flex justify-between">
        <span class="text-slate-500">Estado de Validación:</span>
        <span class="px-2.5 py-0.5 rounded bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 text-xs font-bold uppercase">
          {bank_field(@bank_info, :validation_status)}
        </span>
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :accent, :boolean, default: false

  defp bank_row(assigns) do
    ~H"""
    <div class="flex justify-between border-b border-slate-800/40 pb-2">
      <span class="text-slate-500">{@label}</span>
      <span class={[@accent && "text-indigo-400", "font-bold text-slate-200"]}>{@value}</span>
    </div>
    """
  end

  defp bank_field(bank_info, key) do
    Map.get(bank_info, to_string(key)) || Map.get(bank_info, key)
  end

  attr :show, :boolean, default: false
  attr :form, :any, required: true

  def new_request_modal(assigns) do
    ~H"""
    <div
      :if={@show}
      id="new-modal"
      class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/85 backdrop-blur-md"
    >
      <div class="bg-slate-900 border border-slate-800 w-full max-w-lg rounded-2xl shadow-2xl overflow-hidden">
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
              class="w-full h-12 bg-slate-950 border border-slate-800 text-slate-100 rounded-xl px-4 cursor-pointer"
            >
              <option value="ES" selected={@form[:country].value == "ES"}>España (ES)</option>
              <option value="MX" selected={@form[:country].value == "MX"}>México (MX)</option>
              <option value="CO" selected={@form[:country].value == "CO"}>Colombia (CO)</option>
            </select>
          </div>

          <.input
            field={@form[:full_name]}
            label="Nombre Completo"
            placeholder="Ej. Juan Pérez"
            required
            class={input_class()}
          />
          <.input
            field={@form[:identity_document]}
            label={document_label(@form[:country].value)}
            placeholder={document_placeholder(@form[:country].value)}
            required
            class={input_class() <> " font-mono"}
          />

          <div class="grid grid-cols-2 gap-4">
            <.input
              field={@form[:requested_amount]}
              type="number"
              step="0.01"
              label="Monto Solicitado (€ / $)"
              placeholder="Ej. 3000.00"
              required
              class={input_class()}
            />
            <.input
              field={@form[:monthly_income]}
              type="number"
              step="0.01"
              label="Ingreso Mensual (€ / $)"
              placeholder="Ej. 1500.00"
              required
              class={input_class()}
            />
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
    """
  end

  defp input_class do
    "w-full h-12 bg-slate-950 border-slate-800 focus:border-indigo-500 text-slate-100 rounded-xl px-4"
  end
end
