defmodule Protohackers.BudgetChat.Room do
  use GenServer, restart: :permanent

  require Logger
  use TypedStruct
  alias Protohackers.BudgetChat.User

  @name BudgetChat.Room

  @typep client_list() :: list(User.t())

  typedstruct do
    field(:clients, client_list(), default: [])
  end

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, name: @name)
  end

  @impl true
  def init(:ok) do
    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_call({:register, client_name}, {from_pid, _from_tag}, state) do
    Logger.debug("#{inspect([self(), state])}")

    Enum.each(state.clients, fn %User{pid: pid} ->
      GenServer.cast(pid, {:new_client, client_name})
    end)

    existing_clients = get_client_names(state)

    {:reply, {:ok, existing_clients},
     %{state | clients: [%User{pid: from_pid, name: client_name} | state.clients]}}
  end

  @impl true
  def handle_call(:get_client_names, _from, state) do
    Logger.debug("#{inspect([self(), state])}")
    {:reply, get_client_names(state), state}
  end

  @impl true
  def handle_cast({:send_message, from_pid, from, message}, state) do
    Logger.debug("#{inspect([self(), state])}")

    state.clients
    |> Stream.filter(fn %User{pid: pid} -> pid != from_pid end)
    |> Enum.each(fn %User{pid: pid, name: name} ->
      Logger.debug("sending to #{name}")
      GenServer.cast(pid, {:new_message, from, message})
    end)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:unregister, from_pid, from}, state) do
    Logger.debug("#{inspect([self(), state])}")

    new_clients =
      state.clients
      |> Enum.filter(fn %User{pid: pid} -> pid != from_pid end)

    Enum.each(new_clients, fn %User{pid: pid} ->
      GenServer.cast(pid, {:disconnected, from})
    end)

    {:noreply, %{state | clients: new_clients}}
  end

  @spec register(String.t()) :: {:ok, client_list()}
  def register(client_name) do
    GenServer.call(@name, {:register, client_name})
  end

  @spec unregister(pid(), String.t()) :: :ok
  def unregister(from_pid, from) do
    GenServer.cast(@name, {:unregister, from_pid, from})
  end

  @spec client_names() :: list(String.t())
  def client_names() do
    GenServer.call(@name, :get_client_names)
  end

  @spec send_message(pid(), String.t(), String.t()) :: :ok
  def send_message(from_pid, from, message) do
    GenServer.cast(@name, {:send_message, from_pid, from, message})
  end

  defp get_client_names(state) do
    state.clients |> Enum.map(&Map.fetch!(&1, :name))
  end
end
