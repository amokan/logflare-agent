defmodule LFAgent.LogWatcher do
  @moduledoc """
  Watches a file and sends new lines to the Logflare API each second.
  """

  use GenServer
  require Logger

  @work_delay 1_000

  defstruct id: nil,
            filename: nil,
            source: nil,
            line_count: 0,
            previous_line_count: 0

  @doc """
  Starts a new instance of `LFAgent.LogWatcher`
  """
  def start_link(%{id: id, filename: _, source: _} = state) do
    GenServer.start_link(__MODULE__, state, name: id)
  end

  @doc false
  def init(%{id: id, filename: filename, source: source}) do
    {:ok, %__MODULE__{id: id, filename: filename, source: source}, {:continue, :count_initial_lines}}
  end

  @doc false
  def handle_continue(:count_initial_lines, %__MODULE__{filename: filename, source: source} = state) do
    updated_state =
      with initial_line_count <- filename |> count_lines(),
          _ <- Logger.debug("Watching `#{filename}` from line #{initial_line_count} for source `#{source}...`"),
          do: %__MODULE__{ state | line_count: initial_line_count, previous_line_count: initial_line_count }

    schedule_work()

    {:noreply, updated_state}
  end

  @doc """
  Counts lines in the file, compares to previous line count state.
  If new state is greater than old state, get the new lines and send
  them to Logflare.

  We're concerned with the `filename` and `line_count`.

  If new lines are found we update the `line_count` to reflect the current state of the log file.
  """
  def handle_info(:work, %__MODULE__{filename: filename, line_count: line_count, previous_line_count: line_count} = state) do
    # current line count and previous line count are the same so all we need to do is count the lines now and update the `line_count` attribute
    schedule_work()

    {:noreply, %__MODULE__{ state | line_count: count_lines(filename) }}
  end
  def handle_info(:work, %__MODULE__{filename: filename, line_count: existing_line_count} = state) do
    updated_state =
      with line_count <- filename |> count_lines(),
           sed_opt <- "#{existing_line_count},#{line_count}p",
           {sed, _} <- System.cmd("sed", ["-n", "#{sed_opt}", "#{filename}"]),
           _ <- sed |> String.split("\n", trim: true) |> process_log_entries(state),
           do: %__MODULE__{ state | line_count: line_count, previous_line_count: existing_line_count }

    schedule_work()

    {:noreply, updated_state}
  end

  # iterate and log the new line to logflare
  defp process_log_entries([], _), do: :ok
  defp process_log_entries([line | lines], %__MODULE__{source: source} = state) do
    request =
      with api_key <- System.get_env("LOGFLARE_KEY"),
           url <- "https://logflare.app/api/logs",
           user_agent <- List.to_string(Application.spec(:lfagent, :vsn)),
           headers <- [{"Content-type", "application/json"}, {"X-API-KEY", api_key}, {"User-Agent", "Logflare Agent/#{user_agent}"}],
           body <- Jason.encode!(%{log_entry: line, source: source}),
           do: HTTPoison.post!(url, body, headers)

    case request do
      {:ok, %HTTPoison.Response{status_code: 200}} ->
        :ok
      _ ->
        Logger.error("[LOGFLARE] Something went wrong. Logflare reponded with a #{request.status_code} HTTP status code.")
    end

    process_log_entries(lines, state)
  end

  # count the lines in the file
  defp count_lines(filename) when is_binary(filename) do
    with {wc, _} <- System.cmd("wc", ["-l", filename]),
         [line_count, _] <- String.split(wc),
         do: line_count |> String.to_integer()
  end

  # schedule up the next `:work` callback
  defp schedule_work, do: Process.send_after(self(), :work, @work_delay)
end
