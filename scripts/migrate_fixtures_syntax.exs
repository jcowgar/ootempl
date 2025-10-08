#!/usr/bin/env elixir

# Script to migrate all .docx test fixtures from @...@ syntax to {{...}} syntax

Mix.install([])

defmodule FixtureMigrator do
  @moduledoc """
  Migrates .docx fixtures from old @...@ syntax to new {{...}} syntax.
  """

  def migrate_all_fixtures do
    fixtures_dir = "test/fixtures"

    # Find all .docx files
    docx_files =
      Path.wildcard(Path.join(fixtures_dir, "*.docx"))
      |> Enum.sort()

    IO.puts("Found #{length(docx_files)} .docx files to migrate\n")

    # Process each file
    results = Enum.map(docx_files, fn file ->
      IO.puts("Processing: #{Path.basename(file)}")
      result = migrate_fixture(file)

      case result do
        :ok -> IO.puts("  ✓ Migrated successfully")
        {:error, reason} -> IO.puts("  ✗ Error: #{inspect(reason)}")
      end

      {file, result}
    end)

    # Summary
    IO.puts("\n" <> String.duplicate("=", 60))
    successes = Enum.count(results, fn {_, r} -> r == :ok end)
    failures = Enum.count(results, fn {_, r} -> match?({:error, _}, r) end)

    IO.puts("Migration complete!")
    IO.puts("  Successful: #{successes}")
    IO.puts("  Failed: #{failures}")

    if failures > 0 do
      IO.puts("\nFailed files:")
      Enum.each(results, fn
        {file, {:error, reason}} -> IO.puts("  - #{Path.basename(file)}: #{inspect(reason)}")
        _ -> :ok
      end)
    end
  end

  def migrate_fixture(docx_path) do
    # Create temp directory
    temp_dir = Path.join(System.tmp_dir!(), "ootempl_migrate_#{:rand.uniform(999999)}")

    try do
      # Extract the .docx
      with :ok <- extract_docx(docx_path, temp_dir),
           :ok <- migrate_xml_files(temp_dir),
           :ok <- recompress_docx(temp_dir, docx_path) do
        :ok
      end
    after
      # Cleanup temp directory
      File.rm_rf(temp_dir)
    end
  end

  defp extract_docx(docx_path, temp_dir) do
    case System.cmd("unzip", ["-q", "-d", temp_dir, docx_path], stderr_to_stdout: true) do
      {_, 0} -> :ok
      {output, _} -> {:error, "Failed to extract: #{output}"}
    end
  end

  defp migrate_xml_files(temp_dir) do
    # Find all XML files that might contain placeholders
    xml_patterns = [
      "word/document.xml",
      "word/header*.xml",
      "word/footer*.xml",
      "word/footnotes.xml",
      "word/endnotes.xml",
      "docProps/core.xml",
      "docProps/app.xml"
    ]

    xml_files =
      Enum.flat_map(xml_patterns, fn pattern ->
        Path.wildcard(Path.join(temp_dir, pattern))
      end)

    # Process each XML file
    Enum.reduce_while(xml_files, :ok, fn xml_file, :ok ->
      case migrate_xml_file(xml_file) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp migrate_xml_file(xml_path) do
    case File.read(xml_path) do
      {:ok, content} ->
        migrated = migrate_syntax(content)
        File.write(xml_path, migrated)

      {:error, reason} ->
        {:error, "Failed to read #{xml_path}: #{inspect(reason)}"}
    end
  end

  defp migrate_syntax(xml_content) do
    xml_content
    # Conditionals (must come before regular placeholders to avoid partial matches)
    |> String.replace(~r/@if:([a-zA-Z_][a-zA-Z0-9_.]*)@/i, "{{if \\1}}")
    |> String.replace(~r/@else@/i, "{{else}}")
    |> String.replace(~r/@endif@/i, "{{endif}}")
    # Images
    |> String.replace(~r/@image:([a-zA-Z0-9_-]+)@/, "{{image:\\1}}")
    # Regular placeholders (must come last)
    |> String.replace(~r/@([a-zA-Z_][a-zA-Z0-9_]*(?:\.[a-zA-Z_0-9][a-zA-Z0-9_]*)*)@/, "{{\\1}}")
  end

  defp recompress_docx(temp_dir, output_path) do
    # Word documents require specific compression (mimetype must be first and uncompressed)
    # We'll use the simpler approach of deleting the old file and creating a new zip

    # Convert to absolute path
    abs_output_path = Path.expand(output_path)

    # Change to temp directory for relative paths in zip
    original_dir = File.cwd!()
    File.cd!(temp_dir)

    try do
      # Delete the original file
      File.rm(abs_output_path)

      # Create new zip with all contents
      # The -r flag recursively adds directories, -q is quiet
      case System.cmd("zip", ["-r", "-q", abs_output_path, "."], stderr_to_stdout: true) do
        {_, 0} -> :ok
        {output, _} -> {:error, "Failed to compress: #{output}"}
      end
    after
      File.cd!(original_dir)
    end
  end
end

# Run the migration
FixtureMigrator.migrate_all_fixtures()
