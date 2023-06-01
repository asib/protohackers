defmodule Protohackers.VoraciousCodeStorage.Client do
  use GenServer, restart: :transient

  require Logger

  alias Protohackers.VoraciousCodeStorage.CommandParser
  alias Protohackers.VoraciousCodeStorage.FileSystem

  defstruct [:socket, :buffer]

  def server_socket_opts do
    [packet: :line, active: :once, buffer: 1024 * 100]
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

    state = %{state | buffer: buffer <> data}

    {:ok, {ip, _port}} = :inet.peername(state.socket)
    File.write!("data-#{inspect(ip)}", data, [:append])

    handle_data(state)
  end

  def handle_info({:tcp_closed, _socket}, state) do
    {:stop, :normal, state}
  end

  def handle_data(state) do
    data = state.buffer

    case CommandParser.parse(data) do
      {:error, :no_newline} ->
        Logger.info("#{inspect(state.socket)}: incomplete message, finished parsing")
        :inet.setopts(state.socket, active: :once)
        {:noreply, state}

      {:error, {:illegal_method, method}} ->
        Logger.info("#{inspect(state.socket)}: illegal method: #{method}")
        senderr(state, "illegal method: #{method}")
        {:stop, :normal, state}

      {{:ok, %CommandParser.Put{path: path, length: length}}, rest} ->
        Logger.info("#{inspect(state.socket)}: Reading data\n")

        # First, let's get what we can from the rest of the buffer
        file_read_result =
          case String.slice(rest, 0, length) do
            data when byte_size(data) == length ->
              # If everything's there, return it and whatever is left in the buffer.
              Logger.info("#{inspect(state.socket)}: Got it all\n")
              {data, String.slice(rest, length..-1)}

            data ->
              # If we don't have enough in the buffer, switch to passive
              # mode and read the remaining bytes manually.
              Logger.info(
                "#{inspect(state.socket)}: got #{byte_size(data)}, reading #{length - byte_size(data)} bytes manually\n"
              )

              :inet.setopts(state.socket, packet: :raw)
              tcp_read = :gen_tcp.recv(state.socket, length - byte_size(data))
              :inet.setopts(state.socket, packet: :line)

              case tcp_read do
                {:ok, data_rest} ->
                  Logger.info("#{inspect(state.socket)}: Finished reading\n")

                  {:ok, {ip, _port}} = :inet.peername(state.socket)
                  File.write!("data-#{inspect(ip)}", data_rest, [:append])

                  {data <> data_rest, ""}

                err ->
                  {:error, {:file_read, err}}
              end
          end

        Logger.info("#{inspect(state.socket)}: read file data")

        case file_read_result do
          {:error, _} = err ->
            Logger.info("#{inspect(state.socket)}: #{path} failed to read")
            {:stop, err, state}

          {file_data, buffer_rest} ->
            {:ok, file_revision} = FileSystem.put(path, file_data)
            Logger.info("#{inspect(state.socket)}: #{file_data}")
            sendmsg(state, "OK r#{file_revision}")

            send_ready(state)
            handle_data(%{state | buffer: buffer_rest})
        end

      {result, rest} ->
        case result do
          {:error, {:usage, command}} ->
            Logger.info("#{inspect(state.socket)}: usage: #{usage(command)}\n")
            senderr(state, "usage: #{usage(command)}")

          {:error, :illegal_dir_name} ->
            Logger.info("#{inspect(state.socket)}: illegal dir name\n")
            senderr(state, "illegal dir name")

          {:error, :illegal_file_name} ->
            Logger.info("#{inspect(state.socket)}: illegal file name\n")
            senderr(state, "illegal file name")

          {:error, :invalid_revision} ->
            Logger.info("#{inspect(state.socket)}: no such revision\n")
            senderr(state, "no such revision")
            send_ready(state)

          {:ok, :help} ->
            Logger.info("#{inspect(state.socket)}: HELP\n")
            sendmsg(state, "OK usage: HELP|GET|PUT|LIST")
            send_ready(state)

          {:ok, %CommandParser.List{path: path}} ->
            Logger.info("#{inspect(state.socket)}: #{data}")
            files_in_path = FileSystem.list(path)
            sendmsg(state, "OK #{Enum.count(files_in_path)}")

            Enum.each(files_in_path, fn
              %FileSystem.FileListing{name: name, revision: revision} ->
                sendmsg(state, "#{name} r#{revision}")

              %FileSystem.DirListing{name: name} ->
                sendmsg(state, "#{name}/ DIR")
            end)

            send_ready(state)

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

            send_ready(state)
        end

        handle_data(%{state | buffer: rest})
    end
  end

  defp sendmsg(state, data) do
    :ok = :gen_tcp.send(state.socket, "#{data}\n")
  end

  defp senderr(state, err) do
    sendmsg(state, "ERR #{err}")
  end

  defp send_ready(state) do
    sendmsg(state, "READY")
  end

  defp usage(:list), do: "LIST dir"
  defp usage(:get), do: "GET file [revision]"
  defp usage(:put), do: "PUT file length newline data"
end
