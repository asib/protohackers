defmodule CommandParserTest do
  use ExUnit.Case, async: true

  import Protohackers.VoraciousCodeStorage.CommandParser

  @help_cases [
    {"help", "can parse help"},
    {"help bla bla", "parsing help ignores any input after the command but before the newline"}
  ]

  for {input, case_name} <- @help_cases do
    test case_name do
      assert parse("#{unquote(input)}\n") == {:ok, :help, ""}
    end
  end

  @list_cases [
    {"list /", "/", "can parse list of root"},
    {"list /bla.txt", "/bla.txt", "can parse list of file in root"},
    {"list /bla-testing_new.txt", "/bla-testing_new.txt", "can parse list of file with hyphen"},
    {"list /.", "/.", "can parse list of ."},
    {"list /     ", "/", "can parse list of root with trailing whitespace"}
  ]

  for {input, expected, case_name} <- @list_cases do
    test case_name do
      assert parse("#{unquote(input)}\n") == {:ok, {:list, unquote(expected)}, ""}
    end
  end
end
