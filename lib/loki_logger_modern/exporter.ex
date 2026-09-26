defmodule LokiLoggerModern.Exporter do
  @moduledoc false
  use GenServer

  require Logger

  # Our own diagnostics go through Logger under this domain, which LokiLoggerModern.log/2
  # ignores, so they reach the application's other handlers but are never pushed to Loki.
  @log_opts [domain: [:loki_logger_modern]]

  defmodule State do
    @moduledoc false

    @type t :: %__MODULE__{
            loki_url: String.t(),
            http_headers: [{String.t(), String.t()}],
            loki_labels: any(),
            buffers: list(any()),
            task_ref: any(),
            retry_count: number(),
            retry_delay: number(),
            shutdown_timeout: non_neg_integer()
          }

    defstruct loki_url: nil,
              http_headers: [],
              loki_labels: nil,
              buffers: [],
              task_ref: nil,
              retry_count: 0,
              retry_delay: 0,
              shutdown_timeout: 5_000
  end

  def submit(data) do
    GenServer.call(__MODULE__, {:submit, data})
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(config) do
    # Trap exits so terminate/2 runs on shutdown and pending batches get delivered.
    Process.flag(:trap_exit, true)

    loki_url = config |> Keyword.get(:loki_url)
    http_headers = config |> Keyword.get(:http_headers)
    loki_labels = config |> Keyword.get(:loki_labels)
    retry_count = config |> Keyword.get(:retry_count)
    retry_delay = config |> Keyword.get(:retry_delay)
    shutdown_timeout = config |> Keyword.get(:shutdown_timeout, 5_000)

    state = %State{
      loki_url: loki_url,
      http_headers: http_headers,
      loki_labels: loki_labels,
      retry_count: retry_count,
      retry_delay: retry_delay,
      shutdown_timeout: shutdown_timeout
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:submit, data}, _from, state = %State{}) do
    state.task_ref
    |> case do
      nil ->
        state
        |> push(data)

      _ ->
        buffers = state.buffers ++ [data]
        %{state | buffers: buffers}
    end
    |> then(fn state ->
      {:reply, :ok, state}
    end)
  end

  @impl true
  def handle_info({ref, _result}, state = %State{task_ref: ref}) do
    # We don't care about the DOWN message now, so let's demonitor and flush it
    Process.demonitor(ref, [:flush])

    state
    |> next_task()
    |> then(fn state ->
      {:noreply, state}
    end)
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, %{task_ref: ref} = state) do
    state
    |> next_task()
    |> then(fn state ->
      {:noreply, state}
    end)
  end

  @impl true
  def handle_info(_, state) do
    {:noreply, state}
  end

  # Delivers what's still pending within `shutdown_timeout`: first waits for the in-flight
  # push, then sends the queued batches one by one, without retries.
  @impl true
  def terminate(_reason, %State{} = state) do
    deadline = System.monotonic_time(:millisecond) + state.shutdown_timeout

    await_in_flight(state.task_ref, deadline)

    Enum.each(state.buffers, fn data ->
      if remaining(deadline) > 0 do
        request = build_request(state.loki_url, state.http_headers, state.loki_labels, data)
        send_data_to_loki(request, state.retry_delay, 0, 0)
      end
    end)
  end

  defp await_in_flight(nil, _deadline) do
    :ok
  end

  defp await_in_flight(ref, deadline) do
    receive do
      {^ref, _result} -> Process.demonitor(ref, [:flush])
      {:DOWN, ^ref, :process, _pid, _reason} -> :ok
    after
      remaining(deadline) -> :ok
    end
  end

  defp remaining(deadline) do
    max(deadline - System.monotonic_time(:millisecond), 0)
  end

  defp generate_bin_push_request(loki_labels, output) do
    labels =
      Enum.map(loki_labels, fn {k, v} -> "#{k}=\"#{escape_label_value(v)}\"" end)
      |> Enum.join(",")

    labels = "{" <> labels <> "}"
    # sort entries on epoch seconds as first element of tuple, to prevent out-of-order entries
    sorted_entries =
      output
      |> List.keysort(0)
      |> Enum.map(fn {ts, line} ->
        seconds = Kernel.trunc(ts / 1_000_000_000)
        nanos = ts - seconds * 1_000_000_000

        %LokiLoggerModern.Logproto.EntryAdapter{
          timestamp: %Google.Protobuf.Timestamp{seconds: seconds, nanos: nanos},
          line: line
        }
      end)

    request =
      %LokiLoggerModern.Logproto.PushRequest{
        streams: [
          %LokiLoggerModern.Logproto.StreamAdapter{
            labels: labels,
            entries: sorted_entries
          }
        ]
      }

    request
    |> LokiLoggerModern.Logproto.PushRequest.encode()
    |> SnappyEx.compress()
  end

  # Label values are double-quoted strings in the stream selector.
  defp escape_label_value(value) do
    value
    |> to_string()
    |> String.replace("\\", "\\\\")
    |> String.replace("\"", "\\\"")
    |> String.replace("\n", "\\n")
  end

  defp next_task(state = %State{}) do
    state.buffers
    |> case do
      [] ->
        %{state | task_ref: nil}

      [data | buffers] ->
        %{state | buffers: buffers}
        |> push(data)
    end
  end

  defp build_request(loki_url, http_headers, loki_labels, data) do
    Finch.build(:post, loki_url, http_headers, generate_bin_push_request(loki_labels, data))
  end

  defp send_data_to_loki(request, retry_delay, retry_count, retry_count_current) do
    case Finch.request(request, LokiLoggerModern.Finch) do
      {:ok, %Finch.Response{status: status}} when status in 200..299 ->
        :ok

      {:ok, %Finch.Response{status: status, body: body}} ->
        Logger.error("Unexpected status code from Loki: #{status} #{inspect(body)}", @log_opts)

      {:error, error} ->
        if retry_count < 0 || retry_count_current < retry_count do
          Logger.warning(
            "Push to Loki failed: #{format_error(error)} - retrying in #{retry_delay}ms",
            @log_opts
          )

          :timer.sleep(retry_delay)
          new_count = if retry_count > 0, do: retry_count_current + 1, else: 0
          send_data_to_loki(request, retry_delay, retry_count, new_count)
        else
          Logger.error("Push to Loki failed: #{format_error(error)}", @log_opts)
        end
    end
  end

  defp format_error(error) when is_exception(error) do
    Exception.message(error)
  end

  defp format_error(error) when is_atom(error) or is_binary(error) do
    to_string(error)
  end

  defp format_error(error) do
    inspect(error)
  end

  defp push(%State{} = state, data) do
    %State{loki_url: url, http_headers: headers, loki_labels: labels} = state
    %State{retry_count: count, retry_delay: delay} = state

    task =
      Task.Supervisor.async_nolink(LokiLoggerModern.TaskSupervisor, fn ->
        url
        |> build_request(headers, labels, data)
        |> send_data_to_loki(delay, count, 0)
      end)

    %{state | task_ref: task.ref}
  end
end
