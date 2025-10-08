#!/usr/bin/env elixir

# Script to migrate test files from @...@ syntax to {{...}} syntax
# Only replaces syntax within string literals, not Elixir @ module attributes

defmodule TestMigrator do
  def migrate_all_tests do
    test_files = Path.wildcard("test/**/*.exs")

    IO.puts("Found #{length(test_files)} test files to check\n")

    results =
      Enum.map(test_files, fn file ->
        case migrate_test_file(file) do
          {:ok, :unchanged} ->
            nil

          {:ok, :changed} ->
            IO.puts("✓ Updated: #{file}")
            {file, :ok}

          {:error, reason} ->
            IO.puts("✗ Error in #{file}: #{inspect(reason)}")
            {file, {:error, reason}}
        end
      end)
      |> Enum.reject(&is_nil/1)

    IO.puts("\n" <> String.duplicate("=", 60))
    IO.puts("Updated #{length(results)} files")
  end

  def migrate_test_file(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        migrated = migrate_test_content(content)

        if migrated == content do
          {:ok, :unchanged}
        else
          case File.write(file_path, migrated) do
            :ok -> {:ok, :changed}
            error -> error
          end
        end

      error ->
        error
    end
  end

  defp migrate_test_content(content) do
    content
    # In strings: @if:condition@ -> {{if condition}}
    |> replace_in_strings(~r/@if:([a-zA-Z_][a-zA-Z0-9_.]*)@/i, "{{if \\1}}")
    # In strings: @else@ -> {{else}}
    |> replace_in_strings(~r/@else@/i, "{{else}}")
    # In strings: @endif@ -> {{endif}}
    |> replace_in_strings(~r/@endif@/i, "{{endif}}")
    # In strings: @image:name@ -> {{image:name}}
    |> replace_in_strings(~r/@image:([a-zA-Z0-9_-]+)@/, "{{image:\\1}}")
    # In strings: @variable@ or @nested.path@ -> {{variable}} or {{nested.path}}
    # But NOT @moduledoc, @fixture_path, etc (Elixir module attributes)
    |> replace_in_strings(~r/@([a-zA-Z_][a-zA-Z0-9_]*(?:\.[a-zA-Z_0-9][a-zA-Z0-9_]*)*)@/, "{{\\1}}")
  end

  # Replace pattern only within string literals
  defp replace_in_strings(content, pattern, replacement) do
    # This is a simplified approach - we'll replace in quoted strings
    # Match both single and double quoted strings
    Regex.replace(~r/"([^"]*)"/s, content, fn full_match, string_content ->
      # Only apply replacements inside the string
      new_content = Regex.replace(pattern, string_content, replacement)
      ~s("#{new_content}")
    end)
  end
end

TestMigrator.migrate_all_tests()
