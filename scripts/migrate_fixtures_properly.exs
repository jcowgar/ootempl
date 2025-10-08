#!/usr/bin/env elixir

# Proper fixture migration that handles split placeholders

Mix.install([{:ootempl, path: "."}])

defmodule ProperFixtureMigrator do
  alias Ootempl.{Archive, Xml}

  def migrate_all_fixtures do
    fixtures_dir = "test/fixtures"
    docx_files =
      Path.wildcard(Path.join(fixtures_dir, "*.docx"))
      |> Enum.sort()

    IO.puts("Found #{length(docx_files)} .docx files to migrate\n")

    results = Enum.map(docx_files, fn file ->
      IO.puts("Processing: #{Path.basename(file)}")
      result = migrate_fixture_properly(file)

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
  end

  def migrate_fixture_properly(docx_path) do
    with {:ok, temp_dir} <- Archive.extract(docx_path),
         :ok <- migrate_all_xml_files(temp_dir),
         :ok <- recompress(temp_dir, docx_path) do
      Archive.cleanup(temp_dir)
      :ok
    else
      error ->
        IO.puts("    Error details: #{inspect(error)}")
        error
    end
  end

  defp migrate_all_xml_files(temp_dir) do
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
      case migrate_xml_with_normalization(xml_file) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp migrate_xml_with_normalization(xml_path) do
    with {:ok, xml_string} <- File.read(xml_path),
         {:ok, parsed} <- parse_xml(xml_string),
         normalized <- Xml.Normalizer.normalize(parsed),
         migrated_string <- xml_to_string_with_migration(normalized),
         :ok <- File.write(xml_path, migrated_string) do
      :ok
    else
      error -> error
    end
  end

  defp parse_xml(xml_string) do
    try do
      {doc, _} = :xmerl_scan.string(String.to_charlist(xml_string), quiet: true)
      {:ok, doc}
    rescue
      _ -> {:error, :parse_failed}
    end
  end

  defp xml_to_string_with_migration(xml_element) do
    # Export to string
    xml_list = :xmerl.export_simple([xml_element], :xmerl_xml)
    xml_string = IO.iodata_to_binary(xml_list)

    # Now do the migrations on the merged text
    xml_string
    |> String.replace(~r/@if:([a-zA-Z_][a-zA-Z0-9_.]*)@/i, "{{if \\1}}")
    |> String.replace(~r/@else@/i, "{{else}}")
    |> String.replace(~r/@endif@/i, "{{endif}}")
    |> String.replace(~r/@image:([a-zA-Z0-9_-]+)@/, "{{image:\\1}}")
    |> String.replace(~r/@([a-zA-Z_][a-zA-Z0-9_]*(?:\.[a-zA-Z_0-9][a-zA-Z0-9_]*)*)@/, "{{\\1}}")
  end

  defp recompress(temp_dir, output_path) do
    abs_output_path = Path.expand(output_path)
    original_dir = File.cwd!()
    File.cd!(temp_dir)

    try do
      File.rm(abs_output_path)

      case System.cmd("zip", ["-r", "-q", abs_output_path, "."], stderr_to_stdout: true) do
        {_, 0} -> :ok
        {output, _} -> {:error, "Failed to compress: #{output}"}
      end
    after
      File.cd!(original_dir)
    end
  end
end

ProperFixtureMigrator.migrate_all_fixtures()
