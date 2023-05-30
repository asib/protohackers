defmodule FileSystemTest do
  use ExUnit.Case

  alias Protohackers.VoraciousCodeStorage.FileSystem

  # setup do
  #   start_supervised!({FileSystem, [files: %{}]})
  #   :ok
  # end

  test "can list files" do
    start_supervised!(
      {FileSystem,
       [
         files: %{
           "/" => [
             %FileSystem.File{
               name: "bla.txt",
               revisions: %{1 => "contents"}
             }
           ]
         }
       ]}
    )

    assert FileSystem.list("/") == [
             %FileSystem.File{
               name: "bla.txt",
               revisions: %{1 => "contents"}
             }
           ]
  end
end
