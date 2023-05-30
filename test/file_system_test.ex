defmodule FileSystemTest do
  use ExUnit.Case

  alias Protohackers.VoraciousCodeStorage.FileSystem

  setup do
    start_supervised!({FileSystem, [files: %{}]})
    :ok
  end

  test "can list files" do
    FileSystem.put("/bla.txt", "contents")

    assert FileSystem.list("/") == [
             %FileSystem.File{
               name: "bla.txt",
               revisions: %{1 => "contents"}
             }
           ]
  end
end
