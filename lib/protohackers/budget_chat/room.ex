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

    {:reply, :ok, %{ state | clients: [%User{ pid: from_pid, name: client_name } | state.clients] }}
  end

  @spec register(String.t()) :: :ok
  def register(client_name) do
    GenServer.call(@name, {:register, client_name})
  end
end
