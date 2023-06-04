defmodule Protohackers.MeansToAnEnd.Client do
  use GenServer, restart: :transient

  require Logger

  defstruct [:packet_buffer, :prices]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(_opts) do
    {:ok, %__MODULE__{packet_buffer: <<>>, prices: %{}}}
  end

  @impl true
  def handle_info({:tcp, client_socket, data}, state) do
    Logger.debug("#{inspect(client_socket)}: received data #{inspect(data)}")

    state = %{state | packet_buffer: state.packet_buffer <> data}

    new_state =
      if byte_size(state.packet_buffer) >= 9 do
        {:ok, updated_state} = handle_packet(client_socket, state)
        updated_state
      else
        state
      end

    {:noreply, new_state}
  end

  @impl true
  def handle_info({:tcp_closed, client_socket}, state) do
    Logger.info("#{inspect(client_socket)}: closed connection")
    :ok = :gen_tcp.close(client_socket)

    {:stop, :normal, state}
  end

  def handle_packet(
        client_socket,
        %{
          packet_buffer:
            <<"I", timestamp::integer-32-signed-big, price::integer-32-signed-big,
              packet_buffer_rest::bitstring>>
        } = state
      ) do
    Logger.info(
      "#{inspect(client_socket)}: insert #{Integer.to_string(timestamp)} => #{Integer.to_string(price)}"
    )

    handle_packet(client_socket, %{
      state
      | prices: Map.put(state.prices, timestamp, price),
        packet_buffer: packet_buffer_rest
    })
  end

  def handle_packet(
        client_socket,
        %{
          packet_buffer:
            <<"Q", start_timestamp::integer-32-signed-big, end_timestamp::integer-32-signed-big,
              packet_buffer_rest::bitstring>>
        } = state
      ) do
    Logger.info(
      "#{inspect(client_socket)}: query #{Integer.to_string(start_timestamp)} ≤ T ≤ #{Integer.to_string(end_timestamp)}"
    )

    {price_sum, price_count} =
      state.prices
      |> Map.to_list()
      |> Stream.filter(fn {timestamp, _} ->
        timestamp >= start_timestamp and timestamp <= end_timestamp
      end)
      |> Enum.reduce({0, 0}, fn {_, price}, {sum_acc, price_count} ->
        {sum_acc + price, price_count + 1}
      end)

    average_price =
      if price_count == 0 do
        0
      else
        Integer.floor_div(price_sum, price_count)
      end

    :ok = :gen_tcp.send(client_socket, <<average_price::integer-32-signed-big>>)

    handle_packet(client_socket, %{state | packet_buffer: packet_buffer_rest})
  end

  def handle_packet(_client_socket, %{packet_buffer: packet_buffer} = state)
      when byte_size(packet_buffer) < 9 do
    {:ok, state}
  end
end
