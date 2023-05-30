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

  test "can update file" do
    FileSystem.put("/a", "initial")
    FileSystem.put("/a", "new")

    assert FileSystem.list("/") == [
             %FileSystem.File{
               name: "a",
               revisions: %{1 => "initial", 2 => "new"}
             }
           ]
  end

  test "update_file with new revisions adds initial revision" do
    assert FileSystem.update_file(%FileSystem.File{name: "a", revisions: %{}}, "one") ==
             %FileSystem.File{name: "a", revisions: %{1 => "one"}}
  end

  test "update_file adds new revision" do
    assert FileSystem.update_file(%FileSystem.File{name: "a", revisions: %{1 => "one"}}, "two") ==
             %FileSystem.File{name: "a", revisions: %{1 => "one", 2 => "two"}}
  end
end
