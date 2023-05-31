defmodule Protohackers.VoraciousCodeStorage.CommandParser do
  require Logger

  defmodule List do
    use TypedStruct

    typedstruct do
      field(:path, String.t(), enforce: true)
    end
  end

  defmodule Get do
    use TypedStruct

    typedstruct do
      field(:path, String.t(), enforce: true)
    end
  end

  defmodule Put do
    use TypedStruct

    typedstruct do
      field(:path, String.t(), enforce: true)
      field(:length, integer(), enforce: true)
    end
  end

  @type path :: binary()
  @type error() :: {:error, :invalid_path | :invalid_length | {:illegal_method, String.t()}}
  @type result() :: :help | List.t() | Get.t() | Put.t()
  @spec parse(binary()) :: {:ok, result(), binary()} | :incomplete | error()

  def parse(<<"help", rest::binary>>) do
    with {:ok, _, rest} <- split_on_newline(rest) do
      {:ok, :help, rest}
    end
  end

  def parse(<<"list ", rest::binary>>) do
    with {:ok, path, rest} <- parse_path(rest) do
      {:ok, %List{path: path}, rest}
    end
  end

  def parse(<<"get ", rest::binary>>) do
    with {:ok, path, rest} <- parse_path(rest) do
      {:ok, %Get{path: path}, rest}
    end
  end

  def parse(<<"put ", rest::binary>>) do
    with {:ok, path, rest} <- parse_put_path(rest),
         {:ok, length, rest} <- parse_put_length(rest) do
      {:ok, %Put{path: path, length: length}, rest}
    end
  end

  def parse(data) do
    with {:ok, rest_of_line, _rest} <- split_on_newline(data) do
      {:error, {:illegal_method, rest_of_line |> String.split(" ") |> Elixir.List.first()}}
    end
  end

  defmacro remove_newline_and_match_parts(data, pattern) do
    quote do
      with {:ok, new_data} <- split_newline(unquote(data)) do
        space_split_list = String.split(new_data, " ")

        case space_split_list do
          unquote(pattern) = ret -> {:ok, ret}
          _ -> {:error, :pattern_match_failed}
        end
      end
    end
  end

  def split_newline(data) do
    case String.split(data, "\n") do
      [data, ""] -> {:ok, data}
      _ -> {:error, :no_newline}
    end
  end

  defp parse_put_path(value) do
    with [path, rest] = String.split(value, " ", parts: 2),
         true <- is_path?(path) do
      {:ok, path, rest}
    else
      false -> {:error, :invalid_path}
      _ -> :incomplete
    end
  end

  defp parse_put_length(value) do
    with {:ok, maybe_length, rest} <- split_on_newline(value) do
      cond do
        String.match?(maybe_length, ~r/^[[:digit:]]+/) ->
          %{"length" => length} = Regex.named_captures(~r/^(?<length>[[:digit:]]+)/, maybe_length)
          {:ok, String.to_integer(length), rest}

        String.match?(maybe_length, ~r/^[^[:space:]].*/) ->
          {:ok, 0, rest}

        true ->
          {:error, :invalid_length}
      end
    end
  end

  @spec parse_path(binary()) :: {:ok, path(), binary()} | :incomplete | error()
  defp parse_path(value) do
    with {:ok, maybe_path, rest} <- split_on_newline(value),
         true <- is_path?(maybe_path) do
      {:ok, maybe_path, rest}
    else
      :incomplete -> :incomplete
      _ -> {:error, :invalid_path}
    end
  end

  @spec split_on_newline(binary()) :: {:ok, binary(), binary()} | :incomplete
  defp split_on_newline(command) do
    with [command, rest] <- String.split(command, "\n", parts: 2) do
      {:ok, String.trim_trailing(command), rest}
    else
      _ -> :incomplete
    end
  end

  @spec is_path?(binary()) :: boolean()
  defp is_path?(value) do
    value =~ ~r'^/[[:alnum:]_\-\./]*$'
  end
end
