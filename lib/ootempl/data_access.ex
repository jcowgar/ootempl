defmodule Ootempl.DataAccess do
  @moduledoc """
  Provides data access for nested Elixir data structures with case-insensitive key matching.

  This module enables retrieval of values from nested maps and lists using dot notation paths,
  with automatic case-insensitive key matching and type conversion to strings.

  ## Examples

      iex> data = %{"name" => "John", "age" => 30}
      iex> Ootempl.DataAccess.get_value(data, ["name"])
      {:ok, "John"}

      iex> data = %{"customer" => %{"name" => "Jane"}}
      iex> Ootempl.DataAccess.get_value(data, ["customer", "name"])
      {:ok, "Jane"}

      iex> data = %{"count" => 42}
      iex> Ootempl.DataAccess.get_value(data, ["count"])
      {:ok, "42"}

      iex> data = %{"items" => [%{"price" => 99.99}]}
      iex> Ootempl.DataAccess.get_value(data, ["items", "0", "price"])
      {:ok, "99.99"}

  ## Case-Insensitive Matching

  The module matches keys case-insensitively, so `@Name@`, `@name@`, and `@NAME@`
  all match the same data key:

      iex> data = %{"name" => "John"}
      iex> Ootempl.DataAccess.get_value(data, ["Name"])
      {:ok, "John"}

  If multiple case variants exist, an error is returned:

      iex> data = %{"name" => "John", "Name" => "Jane"}
      iex> Ootempl.DataAccess.get_value(data, ["name"])
      {:error, {:ambiguous_key, "name", ["Name", "name"]}}
  """

  @type path :: [String.t()]
  @type data :: map() | list()
  @type error_reason ::
          {:path_not_found, path()}
          | {:ambiguous_key, String.t(), [String.t() | atom()]}
          | {:conflicting_key_types, String.t(), atom(), String.t()}
          | {:invalid_index, String.t()}
          | {:index_out_of_bounds, non_neg_integer(), non_neg_integer()}
          | {:not_a_list, term()}
          | :nil_value
          | :unsupported_type

  @doc """
  Retrieves a value from nested data using a path with case-insensitive key matching.

  Returns `{:ok, value}` where the value is converted to a string, or `{:error, reason}`
  if the path cannot be resolved.

  ## Parameters

    - `data` - The data structure to traverse (map or list)
    - `path` - List of path segments to navigate (e.g., `["customer", "name"]`)

  ## Returns

    - `{:ok, string}` - The value converted to a string
    - `{:error, reason}` - Error with details about what went wrong

  ## Examples

      iex> Ootempl.DataAccess.get_value(%{"name" => "John"}, ["name"])
      {:ok, "John"}

      iex> Ootempl.DataAccess.get_value(%{"count" => 5}, ["count"])
      {:ok, "5"}

      iex> Ootempl.DataAccess.get_value(%{"active" => true}, ["active"])
      {:ok, "true"}

      iex> Ootempl.DataAccess.get_value(%{}, ["missing"])
      {:error, {:path_not_found, ["missing"]}}
  """
  @spec get_value(data(), path()) :: {:ok, String.t()} | {:error, error_reason()}
  def get_value(data, path) when is_list(path) do
    case traverse(data, path, path) do
      {:ok, value} -> to_string_value(value)
      {:error, _reason} = error -> error
    end
  end

  @spec to_string_value(term()) :: {:ok, String.t()} | {:error, :nil_value | :unsupported_type}
  defp to_string_value(value) when is_binary(value), do: {:ok, value}
  defp to_string_value(value) when is_number(value), do: {:ok, to_string(value)}
  defp to_string_value(true), do: {:ok, "true"}
  defp to_string_value(false), do: {:ok, "false"}
  defp to_string_value(nil), do: {:error, :nil_value}
  defp to_string_value(_), do: {:error, :unsupported_type}

  # Private functions

  @spec traverse(data(), path(), path()) :: {:ok, term()} | {:error, error_reason()}
  defp traverse(data, [], _original_path), do: {:ok, data}

  defp traverse(data, [segment | rest], original_path) when is_map(data) do
    case normalize_key(segment, Map.keys(data)) do
      {:ok, key} ->
        traverse(Map.get(data, key), rest, original_path)

      {:error, {:path_not_found, _}} ->
        {:error, {:path_not_found, original_path}}

      {:error, _reason} = error ->
        error
    end
  end

  defp traverse(data, [segment | rest], original_path) when is_list(data) do
    case parse_index(segment) do
      {:ok, index} ->
        if index < length(data) do
          traverse(Enum.at(data, index), rest, original_path)
        else
          {:error, {:index_out_of_bounds, index, length(data)}}
        end

      {:error, :invalid_index} ->
        {:error, {:invalid_index, segment}}
    end
  end

  defp traverse(_data, _path, original_path) do
    {:error, {:path_not_found, original_path}}
  end

  @spec normalize_key(String.t(), [String.t() | atom()]) ::
          {:ok, String.t() | atom()}
          | {:error,
             {:path_not_found, [String.t()]}
             | {:ambiguous_key, String.t(), [String.t() | atom()]}
             | {:conflicting_key_types, String.t(), atom(), String.t()}}
  defp normalize_key(lookup_key, available_keys) when is_binary(lookup_key) and is_list(available_keys) do
    lowercase_lookup = String.downcase(lookup_key)
    {atom_matches, string_matches} = find_matches(available_keys, lowercase_lookup)
    resolve_key_match(lookup_key, atom_matches, string_matches)
  end

  @spec find_matches([String.t() | atom()], String.t()) :: {[atom()], [String.t()]}
  defp find_matches(available_keys, lowercase_lookup) do
    {atom_keys, string_keys} = Enum.split_with(available_keys, &is_atom/1)

    atom_matches =
      Enum.filter(atom_keys, fn key -> key |> Atom.to_string() |> String.downcase() == lowercase_lookup end)

    string_matches =
      Enum.filter(string_keys, fn key -> String.downcase(key) == lowercase_lookup end)

    {atom_matches, string_matches}
  end

  @spec resolve_key_match(String.t(), [atom()], [String.t()]) ::
          {:ok, String.t() | atom()}
          | {:error,
             {:path_not_found, [String.t()]}
             | {:ambiguous_key, String.t(), [String.t() | atom()]}
             | {:conflicting_key_types, String.t(), atom(), String.t()}}
  defp resolve_key_match(lookup_key, atom_matches, string_matches) do
    case {atom_matches, string_matches} do
      {[], []} ->
        {:error, {:path_not_found, [lookup_key]}}

      {[atom_key], [string_key]} ->
        {:error, {:conflicting_key_types, lookup_key, atom_key, string_key}}

      {[single_atom], []} ->
        {:ok, single_atom}

      {[], [single_string]} ->
        {:ok, single_string}

      {atom_matches, []} when length(atom_matches) > 1 ->
        {:error, {:ambiguous_key, lookup_key, Enum.sort(atom_matches)}}

      {[], string_matches} when length(string_matches) > 1 ->
        {:error, {:ambiguous_key, lookup_key, Enum.sort(string_matches)}}

      {atom_matches, string_matches} ->
        all_matches = Enum.sort(atom_matches ++ string_matches)
        {:error, {:ambiguous_key, lookup_key, all_matches}}
    end
  end

  @spec parse_index(String.t()) :: {:ok, non_neg_integer()} | {:error, :invalid_index}
  defp parse_index(segment) do
    case Integer.parse(segment) do
      {index, ""} when index >= 0 -> {:ok, index}
      _ -> {:error, :invalid_index}
    end
  end
end
