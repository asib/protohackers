defmodule Protohackers.BudgetChat.Room do
  use GenServer, restart: :permanent

  use TypedStruct
  alias Protohackers.BudgetChat.User

  @name BudgetChat.Room

  @typep client_list() :: list(User.t())

  typedstruct do
    field :clients, client_list(), default: []
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
    Enum.each(state.clients, fn %User{pid: pid} ->
      GenServer.cast(pid, {:new_client, client_name})
    end)

    existing_clients = get_client_names(state)
    {:reply, {:ok, existing_clients}, %{ state | clients: [%User{ pid: from_pid, name: client_name } | state.clients] }}
  end

  @impl true
  def handle_call(:get_client_names, _from, state) do
    {:reply, get_client_names(state), state}
  end

  @spec register(String.t()) :: :ok
  def register(client_name) do
    GenServer.call(@name, {:register, client_name})
  end

  @spec client_names() :: list(String.t())
  def client_names() do
    GenServer.call(@name, :get_client_names)
  end

  defp get_client_names(state) do
    state.clients |> Enum.map(&Map.fetch!(&1, :name))
  end
end
