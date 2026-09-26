defmodule LokiLoggerModern.Buffer do
  @moduledoc false
  use GenServer

  defstruct buffer: [],
            buffer_size: 0,
            max_buffer: 32,
            flush_interval: 5_000

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def add(entry) do
    GenServer.cast(__MODULE__, {:add, entry})
  end

  @impl true
  def init(opts) do
    # Trap exits so terminate/2 runs on shutdown and buffered entries aren't lost.
    Process.flag(:trap_exit, true)
    flush_interval = Keyword.get(opts, :flush_interval, 5_000)

    if flush_interval > 0 do
      schedule_flush(flush_interval)
    end

    {:ok,
     %__MODULE__{
       max_buffer: Keyword.get(opts, :max_buffer, 32),
       flush_interval: flush_interval
     }}
  end

  @impl true
  def handle_cast({:add, entry}, %{buffer: buffer, buffer_size: buffer_size} = state) do
    state = %{state | buffer: buffer ++ [entry], buffer_size: buffer_size + 1}

    if state.buffer_size >= state.max_buffer do
      {:noreply, flush(state)}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(:flush, state) do
    schedule_flush(state.flush_interval)
    {:noreply, flush(state)}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    flush(state)
  catch
    # The Exporter is already gone (e.g. it crashed); nothing left to hand the entries to.
    :exit, _ -> :ok
  end

  defp flush(%{buffer_size: 0, buffer: []} = state) do
    state
  end

  defp flush(state) do
    state.buffer |> LokiLoggerModern.Exporter.submit()
    %{state | buffer: [], buffer_size: 0}
  end

  defp schedule_flush(flush_interval) do
    Process.send_after(self(), :flush, flush_interval)
  end
end
