defmodule Protohackers.PrimeTime.Client do
  use GenServer, restart: :transient

  require Logger
  require Jason

  def server_socket_opts do
    [packet: :line]
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(_opts) do
    {:ok, ""}
  end

  @impl true
  def handle_info({:tcp, client_socket, data}, state) do
    Logger.info("#{inspect(client_socket)}: received #{inspect(data)}")

    if String.ends_with?(data, "\n") do
      with {:ok, %{"method" => "isPrime", "number" => n}} when is_number(n) <-
             (state <> data)
             |> String.trim_trailing("\n")
             |> Jason.decode() do
        isPrime = if n <= 1 or not is_integer(n), do: false, else: PrimeTest.test(n)
        response = Jason.encode!(%{method: "isPrime", prime: isPrime})

        Logger.info("#{inspect(client_socket)}: responding #{inspect(response)}")

        :ok = :gen_tcp.send(client_socket, response <> "\n")
      else
        _err ->
          Logger.info("#{inspect(client_socket)}: request malformed, sending malformed response")

          :ok = :gen_tcp.send(client_socket, "\n")
      end

      {:noreply, ""}
    else
      Logger.info("#{inspect(client_socket)}: multi-packet message...")

      {:noreply, state <> data}
    end
  end

  @impl true
  def handle_info({:tcp_closed, client_socket}, "") do
    Logger.info("#{inspect(client_socket)}: client closed connection, writing data and closing")

    :ok = :gen_tcp.close(client_socket)

    {:stop, :normal, nil}
  end
end
