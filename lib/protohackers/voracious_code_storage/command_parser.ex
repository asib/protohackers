defmodule Protohackers.VoraciousCodeStorage.CommandParser do
  require Logger

  defmacro match_space_separated_parts(data, pattern) do
    quote do
      space_split_list = unquote(data) |> String.trim_trailing() |> String.split(" ")

      case space_split_list do
        unquote(pattern) = ret -> {:ok, ret}
        _ -> {:error, :pattern_match_failed}
      end
    end
  end

  def split_newline(data) do
    case String.split(data, "\n") do
      [data, ""] -> {:ok, data}
      _ -> {:error, :no_newline}
    end
  end

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
  def parse(data) do
    with {:ok, data} <- split_newline(data) do
      parse_command(data)
    end
  end

  def parse_command(<<"help", _rest::binary>>) do
    {:ok, :help}
  end

  def parse_command(<<"list", _rest::binary>> = data) do
    with {:ok, ["list", dir_path]} <- match_space_separated_parts(data, ["list", _]),
         true <- is_path?(dir_path) do
      {:ok, %List{path: dir_path}}
    else
      {:error, :pattern_match_failed} -> {:error, {:usage, :list}}
      false -> {:error, :illegal_dir_name}
    end
  end

  def parse_command(<<"get", _rest::binary>> = data) do
    with {:ok, ["get", file_path]} <- match_space_separated_parts(data, ["get", _]),
         true <- is_path?(file_path),
         true <- !String.ends_with?(file_path, "/") do
      {:ok, %Get{path: file_path}}
    else
      {:error, :pattern_match_failed} -> {:error, {:usage, :get}}
      false -> {:error, :illegal_file_name}
    end
  end

  def parse_command(<<"put", _rest::binary>> = data) do
    with {:ok, ["put", path, length]} <- match_space_separated_parts(data, ["put", _, _]),
         true <- is_path?(path),
         true <- !String.ends_with?(path, "/"),
         {:ok, valid_length} <-
           parse_valid_length(length) do
      {:ok, %Put{path: path, length: valid_length}}
    else
      {:error, :pattern_match_failed} -> {:error, {:usage, :put}}
      false -> {:error, :illegal_file_name}
      {:error, :invalid_length} = err -> err
    end
  end

  def parse_command(data) do
    {:error, {:illegal_method, data |> String.split(" ") |> Elixir.List.first()}}
  end

  defp parse_valid_length(maybe_length) do
    cond do
      String.match?(maybe_length, ~r/^[[:digit:]]+/) ->
        %{"length" => length} = Regex.named_captures(~r/^(?<length>[[:digit:]]+)/, maybe_length)
        {:ok, String.to_integer(length)}

      String.match?(maybe_length, ~r/^[^[:space:]].*/) ->
        {:ok, 0}

      true ->
        {:error, :invalid_length}
    end
  end

  @spec is_path?(binary()) :: boolean()
  defp is_path?(value) do
    value =~ ~r'^/[[:alnum:]_\-\./]*$'
  end
end
