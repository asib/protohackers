defmodule EchoServer.Client do
  use GenServer, restart: :transient

  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  @spec init(any) :: {:ok, <<>>}
  def init(_opts) do
    {:ok, <<>>}
  end

  @impl true
  def handle_info({:tcp, client_socket, data}, state) do
    Logger.info("received #{inspect(data)} from #{inspect(client_socket)}")

    {:noreply, state <> data}
  end

  @impl true
  def handle_info({:tcp_closed, client_socket}, state) do
    Logger.info("client closed connection, writing data and closing: #{inspect(client_socket)}")

    :ok = :gen_tcp.send(client_socket, state)
    :ok = :gen_tcp.close(client_socket)

    {:stop, :normal, state}
  end
end
