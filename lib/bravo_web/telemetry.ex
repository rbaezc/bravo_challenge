defmodule BravoWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      # Telemetry poller will execute the given period measurements
      # every 10_000ms. Learn more here: https://hexdocs.pm/telemetry_metrics
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000},

      # Prometheus reporter: aggregates the metrics below and exposes them via
      # `TelemetryMetricsPrometheus.Core.scrape/0` (served at GET /metrics).
      {TelemetryMetricsPrometheus.Core, metrics: prometheus_metrics()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  Prometheus-compatible metrics (counter / distribution only), scraped at
  `/metrics`. Covers HTTP latency, the credit-request use cases, the background
  queues (Oban) and outbound webhook deliveries.
  """
  def prometheus_metrics do
    [
      # HTTP request latency
      distribution("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond},
        reporter_options: [buckets: [10, 50, 100, 250, 500, 1000, 2500]]
      ),

      # Business: credit request use cases
      counter("bravo.use_case.create_credit_request.stop.duration",
        description: "Credit requests created"
      ),
      counter("bravo.use_case.update_credit_request.stop.duration",
        description: "Credit requests updated"
      ),

      # Background queues (Oban): completions and failures by queue/worker
      counter("oban.job.stop.count",
        event_name: [:oban, :job, :stop],
        measurement: :duration,
        tags: [:queue, :worker],
        description: "Oban jobs completed"
      ),
      counter("oban.job.exception.count",
        event_name: [:oban, :job, :exception],
        measurement: :duration,
        tags: [:queue, :worker],
        description: "Oban jobs failed"
      ),
      distribution("oban.job.stop.duration",
        tags: [:queue],
        unit: {:native, :millisecond},
        reporter_options: [buckets: [50, 100, 250, 500, 1000, 5000]]
      ),

      # Outbound webhook deliveries by result
      counter("bravo.webhook.sent.count",
        tags: [:result],
        description: "Outbound status-change webhooks attempted"
      )
    ]
  end

  def metrics do
    [
      # Phoenix Metrics
      summary("phoenix.endpoint.start.system_time",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.start.system_time",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.exception.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.socket_connected.duration",
        unit: {:native, :millisecond}
      ),
      sum("phoenix.socket_drain.count"),
      summary("phoenix.channel_joined.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.channel_handled_in.duration",
        tags: [:event],
        unit: {:native, :millisecond}
      ),

      # Database Metrics
      summary("bravo.repo.query.total_time",
        unit: {:native, :millisecond},
        description: "The sum of the other measurements"
      ),
      summary("bravo.repo.query.decode_time",
        unit: {:native, :millisecond},
        description: "The time spent decoding the data received from the database"
      ),
      summary("bravo.repo.query.query_time",
        unit: {:native, :millisecond},
        description: "The time spent executing the query"
      ),
      summary("bravo.repo.query.queue_time",
        unit: {:native, :millisecond},
        description: "The time spent waiting for a database connection"
      ),
      summary("bravo.repo.query.idle_time",
        unit: {:native, :millisecond},
        description:
          "The time the connection spent waiting before being checked out for the query"
      ),

      # VM Metrics
      summary("vm.memory.total", unit: {:byte, :kilobyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io")
    ]
  end

  defp periodic_measurements do
    [
      # A module, function and arguments to be invoked periodically.
      # This function must call :telemetry.execute/3 and a metric must be added above.
      # {BravoWeb, :count_users, []}
    ]
  end
end
