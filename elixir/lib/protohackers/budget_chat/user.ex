defmodule Protohackers.BudgetChat.User do
  use TypedStruct

  typedstruct do
    field(:pid, pid(), enforce: true)
    field(:name, String.t(), enforce: true)
  end
end
