defmodule Protohackers.UnusualDatabaseProgram.Client do
  use GenServer, restart: :permanent

  require Logger

  def udp_server, do: nil

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(_opts) do
    db = :ets.new(__MODULE__, [:set, :public])

    {:ok, db}
  end

  @impl true
  def handle_info({:udp, server_socket, client_ip, client_port, msg}, db) do
    msg = String.trim(msg)

    if String.contains?(msg, "=") do
      handle_insert(msg, db)
    else
      handle_query(server_socket, client_ip, client_port, msg, db)
    end
  end

  defp handle_insert(msg, db) do
    Logger.info("inserting #{msg}")

    [key, value] = String.split(msg, "=", parts: 2)
    true = :ets.insert(db, {key, value})

    {:noreply, db}
  end

  defp handle_query(socket, client_ip, client_port, msg, db) do
    Logger.info("querying #{msg}")

    value =
      case msg do
        "version" ->
          "Ken's Key-Value Store 1.0"

        _ ->
          case :ets.lookup(db, msg) do
            [{^msg, value}] -> value
            _ -> ""
          end
      end

    :gen_udp.send(socket, client_ip, client_port, "#{msg}=#{value}")

    {:noreply, db}
  end
end
