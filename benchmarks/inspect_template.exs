# Inspect what's inside a loaded Template struct
#
# Run with: mix run benchmarks/inspect_template.exs

{:ok, template} = Ootempl.load("test/fixtures/Simple Placeholders.docx")

IO.puts("\n=== Template Struct Contents ===\n")

IO.puts("1. document (main content)")
IO.puts("   Type: #{inspect(elem(template.document, 0))}")
IO.puts("   This is the parsed and normalized XML from word/document.xml")
IO.puts("   Contains paragraphs, runs, text, tables, images, etc.")
IO.puts("")

IO.puts("2. headers")
IO.puts("   Count: #{map_size(template.headers)}")
if map_size(template.headers) > 0 do
  IO.puts("   Files:")
  template.headers |> Map.keys() |> Enum.sort() |> Enum.each(&IO.puts("     - #{&1}"))
else
  IO.puts("   (no headers in this template)")
end
IO.puts("")

IO.puts("3. footers")
IO.puts("   Count: #{map_size(template.footers)}")
if map_size(template.footers) > 0 do
  IO.puts("   Files:")
  template.footers |> Map.keys() |> Enum.sort() |> Enum.each(&IO.puts("     - #{&1}"))
else
  IO.puts("   (no footers in this template)")
end
IO.puts("")

IO.puts("4. footnotes")
IO.puts("   Present: #{if template.footnotes, do: "yes", else: "no"}")
IO.puts("   Parsed XML from word/footnotes.xml (if exists)")
IO.puts("")

IO.puts("5. endnotes")
IO.puts("   Present: #{if template.endnotes, do: "yes", else: "no"}")
IO.puts("   Parsed XML from word/endnotes.xml (if exists)")
IO.puts("")

IO.puts("6. core_properties")
IO.puts("   Present: #{if template.core_properties, do: "yes", else: "no"}")
IO.puts("   Parsed XML from docProps/core.xml (title, author, etc.)")
IO.puts("")

IO.puts("7. app_properties")
IO.puts("   Present: #{if template.app_properties, do: "yes", else: "no"}")
IO.puts("   Parsed XML from docProps/app.xml (company, manager, etc.)")
IO.puts("")

IO.puts("8. static_files")
IO.puts("   Count: #{map_size(template.static_files)} files")
IO.puts("   These are binary files that don't need processing:")
template.static_files
|> Map.keys()
|> Enum.sort()
|> Enum.each(fn path ->
  size = byte_size(Map.get(template.static_files, path))
  IO.puts("     - #{path} (#{size} bytes)")
end)
IO.puts("")

IO.puts("9. source_path")
IO.puts("   Value: #{inspect(template.source_path)}")
IO.puts("   Original template file path (for reference)")
IO.puts("")

IO.puts("\n=== Summary ===\n")

# Calculate total memory footprint
xml_count = 1 + map_size(template.headers) + map_size(template.footers)
xml_count = if template.footnotes, do: xml_count + 1, else: xml_count
xml_count = if template.endnotes, do: xml_count + 1, else: xml_count
xml_count = if template.core_properties, do: xml_count + 1, else: xml_count
xml_count = if template.app_properties, do: xml_count + 1, else: xml_count

static_size = template.static_files |> Map.values() |> Enum.map(&byte_size/1) |> Enum.sum()

IO.puts("Parsed XML structures: #{xml_count} documents")
IO.puts("Static files: #{map_size(template.static_files)} files (#{static_size} bytes)")
IO.puts("")
IO.puts("All XML has been:")
IO.puts("  ✓ Extracted from .docx ZIP")
IO.puts("  ✓ Parsed with :xmerl")
IO.puts("  ✓ Normalized (fragmented placeholders collapsed)")
IO.puts("  ✓ Ready for fast cloning and rendering")
IO.puts("")
