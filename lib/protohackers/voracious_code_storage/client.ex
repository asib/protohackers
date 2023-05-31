defmodule Protohackers.VoraciousCodeStorage.Client do
  use GenServer, restart: :transient

  require Logger

  alias Protohackers.VoraciousCodeStorage.CommandParser
  alias Protohackers.VoraciousCodeStorage.FileSystem

  defstruct [:socket, :buffer]

  def server_socket_opts do
    [packet: :line, active: :once]
  end

  def applications do
    [{FileSystem, [files_by_path: %{}]}]
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(tcp_socket: socket) do
    {:ok, %__MODULE__{socket: socket, buffer: <<>>}, {:continue, :ready}}
  end

  def handle_continue(:ready, state) do
    Logger.info("READY\n")
    sendmsg(state, "READY")

    {:noreply, state}
  end

  def handle_info({:tcp, _socket, data}, %{buffer: buffer} = state) do
    Logger.info("#{inspect(state.socket)}: #{inspect(data)}")

    case CommandParser.parse(data) do
      {:error, :no_newline} ->
        Logger.error("#{inspect(state.socket)}: got incomplete message")
        noreply(%{state | buffer: buffer <> data})

      {:error, {:illegal_method, method}} ->
        Logger.info("#{inspect(state.socket)}: illegal method: #{method}")
        senderr(state, "illegal method: #{method}")
        {:stop, :normal, state}

      {:error, {:usage, command}} ->
        Logger.info("#{inspect(state.socket)}: usage: #{usage(command)}\n")
        senderr(state, "usage: #{usage(command)}")
        noreply(state)

      {:error, :illegal_dir_name} ->
        Logger.info("#{inspect(state.socket)}: illegal dir name\n")
        senderr(state, "illegal dir name")
        noreply(state)

      {:error, :illegal_file_name} ->
        Logger.info("#{inspect(state.socket)}: illegal file name\n")
        senderr(state, "illegal file name")
        noreply(state)

      {:error, :invalid_revision} ->
        Logger.info("#{inspect(state.socket)}: no such revision\n")
        senderr(state, "no such revision")
        ready(state)

      {:ok, :help} ->
        Logger.info("#{inspect(state.socket)}: HELP\n")
        sendmsg(state, "OK usage: HELP|GET|PUT|LIST")
        ready(state)

      {:ok, %CommandParser.List{path: path}} ->
        Logger.info("#{inspect(state.socket)}: #{data}")
        files_in_path = FileSystem.list(path)
        sendmsg(state, "OK #{Enum.count(files_in_path)}")

        Enum.each(files_in_path, fn file_listing ->
          sendmsg(state, "#{file_listing.name} r#{file_listing.revision}")
        end)

        ready(state)

      {:ok, %CommandParser.Get{path: path, revision: revision}} ->
        Logger.info("#{inspect(state.socket)}: #{data}")

        case FileSystem.get(path, revision) do
          {:error, :no_such_file} ->
            senderr(state, "no such file")

          {:ok, file_data} ->
            sendmsg(state, "OK #{byte_size(file_data)}")
            # Using raw send to avoid appending newline.
            :gen_tcp.send(state.socket, file_data)
        end

        ready(state)

      {:ok, %CommandParser.Put{path: path, length: length}} ->
        Logger.info("#{inspect(state.socket)}: #{data}")
        :inet.setopts(state.socket, packet: :raw)

        case :gen_tcp.recv(state.socket, length) do
          {:ok, file_data} ->
            {:ok, file_revision} = FileSystem.put(path, file_data)
            sendmsg(state, "OK r#{file_revision}")

            ready(state)

          err ->
            Logger.error(inspect(err))
        end

        Logger.info("#{inspect(state.socket)}: read file data")

        :inet.setopts(state.socket, packet: :line)
        ready(state)
    end
  end

  def handle_info({:tcp_closed, _socket}, state) do
    {:stop, :normal, state}
  end

  defp sendmsg(state, data) do
    :ok = :gen_tcp.send(state.socket, "#{data}\n")
  end

  defp senderr(state, err) do
    sendmsg(state, "ERR #{err}")
  end

  defp ready(state) do
    :inet.setopts(state.socket, active: :once)
    {:noreply, state, {:continue, :ready}}
  end

  defp noreply(state) do
    :inet.setopts(state.socket, active: :once)
    {:noreply, state}
  end

  defp usage(:list), do: "LIST dir"
  defp usage(:get), do: "GET file [revision]"
  defp usage(:put), do: "PUT file length newline data"
end
