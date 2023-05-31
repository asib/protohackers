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
    :ok = :gen_tcp.send(state.socket, "READY\n")

    {:noreply, state}
  end

  def handle_info({:tcp, _socket, data}, %{buffer: buffer} = state) do
    case CommandParser.parse(data) do
      :incomplete ->
        Logger.error("got incomplete message")
        {:noreply, %{state | buffer: buffer <> data}}

      {:error, {:illegal_method, method}} ->
        Logger.info("illegal method: #{method}")
        :gen_tcp.send(state.socket, "ERR illegal method: #{method}\n")
        {:stop, :normal, state}

      {:ok, %CommandParser.List{path: path}, ""} ->
        files_in_path = FileSystem.list(path)
        :gen_tcp.send(state.socket, "OK #{Enum.count(files_in_path)}\n")

        Enum.each(files_in_path, fn file_listing ->
          :gen_tcp.send(state.socket, "#{file_listing.name} r#{file_listing.revision}\n")
        end)

        {:noreply, state, {:continue, :ready}}

      {:ok, %CommandParser.Get{path: path}, ""} ->
        contents = FileSystem.get(path)
    end
  end
end
