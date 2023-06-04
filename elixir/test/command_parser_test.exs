defmodule CommandParserTest do
  use ExUnit.Case, async: true

  import Protohackers.VoraciousCodeStorage.CommandParser
  alias Protohackers.VoraciousCodeStorage.CommandParser

  @help_success_cases [
    {"help", "can parse help"},
    {"help bla bla", "parsing help ignores any input after the command but before the newline"}
  ]

  for {input, case_name} <- @help_success_cases do
    test case_name do
      assert parse_command("#{unquote(input)}") == {:ok, :help}
    end
  end

  @list_success_cases [
    {"/bla.txt", "/bla.txt", "can parse file in root"},
    {"/bla-testing_new.txt", "/bla-testing_new.txt", "can parse file with hyphen"},
    {"/.", "/.", "can parse /."}
  ]

  for {input, expected, case_name} <- @list_success_cases do
    test "list: #{case_name}" do
      assert parse_command("list #{unquote(input)}") ==
               {:ok, %CommandParser.List{path: unquote(expected)}}
    end
  end

  @get_success_cases [
    {"/bla.txt", "/bla.txt", "can parse file in root"},
    {"/bla-testing_new.txt", "/bla-testing_new.txt", "can parse file with hyphen"},
    {"/.", "/.", "can parse /."}
  ]

  for {input, expected, case_name} <- @get_success_cases do
    test "get: #{case_name}" do
      assert parse_command("get #{unquote(input)}") ==
               {:ok, %CommandParser.Get{path: unquote(expected), revision: :latest}}
    end
  end

  @get_revision_success_cases [
    "1",
    "r1",
    "1rrr",
    "r1rrr"
  ]

  for input <- @get_revision_success_cases do
    test "can parse get with revision: #{inspect(input)}" do
      assert parse_command("get /a #{unquote(input)}") ==
               {:ok, %CommandParser.Get{path: "/a", revision: 1}}
    end
  end

  @put_success_cases [
    {"/bla.txt 5", {"/bla.txt", 5}, "can parse put"},
    {"/test 2b", {"/test", 2}, "ignore characters after length but before newline"},
    {"/test bla", {"/test", 0}, "(1): non-numeric length is parsed as 0"},
    {"/test _", {"/test", 0}, "(2): non-numeric length is parsed as 0"}
  ]

  for {input, {path, length}, case_name} <- @put_success_cases do
    test case_name do
      assert parse_command("put #{unquote(input)}") ==
               {:ok, %CommandParser.Put{path: unquote(path), length: unquote(length)}}
    end
  end

  @incomplete_cases [
    "help",
    "get /bla.txt",
    "list ",
    "put /bla.txt 15",
    "put /bla.txt ddfkdfd"
  ]

  for input <- @incomplete_cases do
    test "incomplete: #{inspect(input)}" do
      assert parse(unquote(input)) == {:error, :no_newline}
    end
  end

  test "list: can parse root" do
    assert parse_command("list /") == {:ok, %CommandParser.List{path: "/"}}
    assert parse_command("list /           ") == {:ok, %CommandParser.List{path: "/"}}
  end

  test "list: illegal usage" do
    assert parse_command("list / abc") == {:error, {:usage, :list}}
    assert parse_command("list a b c") == {:error, {:usage, :list}}
  end

  test "list: illegal dir name" do
    assert parse_command("list abc") == {:error, :illegal_dir_name}
    assert parse_command("list /$^%£&£@") == {:error, :illegal_dir_name}
  end

  test "get: illegal usage" do
    assert parse_command("get /a b c") == {:error, {:usage, :get}}
    assert parse_command("get a b c") == {:error, {:usage, :get}}
  end

  test "get: illegal file name" do
    assert parse_command("get /") == {:error, :illegal_file_name}
    assert parse_command("get /a/") == {:error, :illegal_file_name}
    assert parse_command("get /%") == {:error, :illegal_file_name}
    assert parse_command("get /\\") == {:error, :illegal_file_name}
  end

  test "put: illegal usage" do
    assert parse_command("put a b c d e f") == {:error, {:usage, :put}}
  end

  test "put: illegal file name" do
    assert parse_command("put / 1") == {:error, :illegal_file_name}
    assert parse_command("put /a/ 1") == {:error, :illegal_file_name}
    assert parse_command("put /% 1") == {:error, :illegal_file_name}
    assert parse_command("put /\\ 1") == {:error, :illegal_file_name}
  end

  test "put: can't have more than one space after file path" do
    assert parse_command("put /test       $$$$$") == {:error, {:usage, :put}}
  end

  test "illegal method" do
    assert parse_command("testing") == {:error, {:illegal_method, "testing"}}
    assert parse_command("testing bla bla bla") == {:error, {:illegal_method, "testing"}}
  end

  test "remove_newline_and_match_parts" do
    assert CommandParser.match_space_separated_parts("list /", ["list", "/"]) ==
             {:ok, ["list", "/"]}

    assert CommandParser.match_space_separated_parts("list /     ", ["list", _]) ==
             {:ok, ["list", "/"]}

    assert CommandParser.match_space_separated_parts(
             "put a b c d e f",
             [
               "put",
               _,
               _,
               _,
               _,
               _,
               _
             ]
           ) == {:ok, ["put", "a", "b", "c", "d", "e", "f"]}
  end

  test "can parse invalid revision" do
    assert parse_command("get /a rrrr1\n") == {:error, :invalid_revision}
  end

  test "parse case-insensitively" do
    assert parse("LiSt /\n") == {{:ok, %CommandParser.List{path: "/"}}, ""}
  end

  test "returns rest of data" do
    assert parse("help   \ntesting") == {{:ok, :help}, "testing"}
  end

  test "can parse put readme from protohackers suite" do
    file_data = File.read!("kilo_readme.md")
    readme_cmd = ~s"PUT /kilo.0001/README.md 735\n#{file_data}"

    assert parse(readme_cmd) ==
             {{:ok, %CommandParser.Put{path: "/kilo.0001/README.md", length: 735}}, file_data}
  end
end
