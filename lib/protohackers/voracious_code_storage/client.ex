defmodule Protohackers.VoraciousCodeStorage.Client do
  use GenServer, restart: :transient

  require Logger

  alias Protohackers.VoraciousCodeStorage.CommandParser
  alias Protohackers.VoraciousCodeStorage.FileSystem

  defstruct [:socket, :buffer]

  def server_socket_opts do
    [packet: :line]
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
    sendmsg(state, "READY")

    {:noreply, state}
  end

  def handle_info({:tcp, _socket, data}, %{buffer: buffer} = state) do
    case CommandParser.parse(data) do
      {:error, :no_newline} ->
        Logger.error("got incomplete message")
        noreply(%{state | buffer: buffer <> data})

      {:error, {:illegal_method, method}} ->
        Logger.info("illegal method: #{method}")
        senderr(state, "illegal method: #{method}")
        {:stop, :normal, state}

      {:error, {:usage, command}} ->
        Logger.info("usage: #{usage(command)}\n")
        senderr(state, "usage: #{usage(command)}")
        noreply(state)

      {:error, :illegal_dir_name} ->
        senderr(state, "illegal dir name")
        noreply(state)

      {:error, :illegal_file_name} ->
        senderr(state, "illegal file name")
        noreply(state)

      {:error, :invalid_revision} ->
        senderr(state, "no such revision")
        ready(state)

      {:ok, :help} ->
        sendmsg(state, "OK usage: HELP|GET|PUT|LIST")
        ready(state)

      {:ok, %CommandParser.List{path: path}} ->
        files_in_path = FileSystem.list(path)
        sendmsg(state, "OK #{Enum.count(files_in_path)}")

        Enum.each(files_in_path, fn file_listing ->
          sendmsg(state, "#{file_listing.name} r#{file_listing.revision}")
        end)

        ready(state)

      {:ok, %CommandParser.Get{path: path, revision: revision}} ->
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
        :inet.setopts(state.socket, active: false, packet: :raw)

        case :gen_tcp.recv(state.socket, length) do
          {:ok, file_data} ->
            {:ok, file_revision} = FileSystem.put(path, file_data)
            sendmsg(state, "OK r#{file_revision}")

            ready(state)

          err ->
            Logger.error(inspect(err))
        end

        :inet.setopts(state.socket, active: true, packet: :line)
        ready(state)
    end
  end

  defp sendmsg(state, data) do
    :ok = :gen_tcp.send(state.socket, "#{data}\n")
  end

  defp senderr(state, err) do
    sendmsg(state, "ERR #{err}")
  end

  defp ready(state) do
    # :inet.setopts(state.socket, active: :once)
    {:noreply, state, {:continue, :ready}}
  end

  defp noreply(state) do
    # :inet.setopts(state.socket, active: :once)
    {:noreply, state}
  end

  defp usage(:list), do: "LIST dir"
  defp usage(:get), do: "GET file [revision]"
  defp usage(:put), do: "PUT file length newline data"
end
