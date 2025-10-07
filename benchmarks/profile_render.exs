# Profiling script for Ootempl document rendering with flame graphs
#
# This script uses eflambe to generate interactive flame graphs showing
# where time is being spent during document rendering.
#
# Run with: mix run benchmarks/profile_render.exs
#
# Flame graphs will be saved in benchmarks/profiles/

# Setup output directories
profile_dir = "benchmarks/profiles"
output_dir = "benchmarks/output"
File.mkdir_p!(profile_dir)
File.mkdir_p!(output_dir)

# Helper to generate test data
defmodule ProfileHelpers do
  def generate_table_data(num_rows) do
    Enum.map(1..num_rows, fn i ->
      %{
        "id" => Integer.to_string(5000 + i),
        "amount" => Float.to_string(:rand.uniform(1000) + 0.50)
      }
    end)
  end

  def generate_simple_data do
    %{
      "name" => "John Doe",
      "email" => "john.doe@example.com",
      "company" => "Acme Corporation",
      "address" => "123 Main Street",
      "city" => "Springfield",
      "state" => "IL",
      "zip" => "62701",
      "phone" => "(555) 123-4567",
      "date" => "October 7, 2025",
      "invoice_number" => "INV-2025-001234",
      "total" => "1,234.56"
    }
  end
end

IO.puts("\n=== Ootempl Performance Profiling ===\n")
IO.puts("Generating flame graphs for different scenarios...")
IO.puts("Flame graphs will be saved to: #{profile_dir}\n")

# Profile 1: Simple placeholder replacement
IO.puts("1. Profiling simple placeholder replacement...")

{:ok, stacks} =
  :eflambe.capture(fn ->
    data = ProfileHelpers.generate_simple_data()
    output = "#{output_dir}/profile_simple.docx"

    # Run multiple iterations for better profiling data
    Enum.each(1..50, fn _i ->
      Ootempl.render("test/fixtures/Simple Placeholders.docx", data, output)
      File.rm(output)
    end)
  end)

:ok = :eflambe.apply(:stacks_to_flame, [stacks, "#{profile_dir}/simple_placeholders.bggg"])
IO.puts("   → Flame graph saved: #{profile_dir}/simple_placeholders.svg")

# Profile 2: Table with 25 rows
IO.puts("\n2. Profiling table rendering (25 rows)...")

{:ok, stacks} =
  :eflambe.capture(fn ->
    data = %{
      "title" => "Invoice Report",
      "date" => "October 7, 2025",
      "claims" => ProfileHelpers.generate_table_data(25),
      "total" => "12,345.67"
    }

    output = "#{output_dir}/profile_table.docx"

    Enum.each(1..50, fn _i ->
      Ootempl.render("test/fixtures/table_simple.docx", data, output)
      File.rm(output)
    end)
  end)

:ok = :eflambe.apply(:stacks_to_flame, [stacks, "#{profile_dir}/table_25_rows.bggg"])
IO.puts("   → Flame graph saved: #{profile_dir}/table_25_rows.svg")

# Profile 3: Table with 50 rows (more data)
IO.puts("\n3. Profiling table rendering (50 rows)...")

{:ok, stacks} =
  :eflambe.capture(fn ->
    data = %{
      "title" => "Invoice Report",
      "date" => "October 7, 2025",
      "claims" => ProfileHelpers.generate_table_data(50),
      "total" => "12,345.67"
    }

    output = "#{output_dir}/profile_table_50.docx"

    Enum.each(1..50, fn _i ->
      Ootempl.render("test/fixtures/table_simple.docx", data, output)
      File.rm(output)
    end)
  end)

:ok = :eflambe.apply(:stacks_to_flame, [stacks, "#{profile_dir}/table_50_rows.bggg"])
IO.puts("   → Flame graph saved: #{profile_dir}/table_50_rows.svg")

# Profile 4: Comprehensive template
IO.puts("\n4. Profiling comprehensive template...")

{:ok, stacks} =
  :eflambe.capture(fn ->
    data = %{
      "document_title" => "Comprehensive Document",
      "company_name" => "Acme Corp",
      "footnote_ref" => "Reference 1",
      "endnote_text" => "Additional notes",
      "person" => %{"first_name" => "John Doe"},
      "date" => "2025-10-07"
    }

    output = "#{output_dir}/profile_comprehensive.docx"

    Enum.each(1..50, fn _i ->
      Ootempl.render("test/fixtures/comprehensive_template.docx", data, output)
      File.rm(output)
    end)
  end)

:ok = :eflambe.apply(:stacks_to_flame, [stacks, "#{profile_dir}/comprehensive.bggg"])
IO.puts("   → Flame graph saved: #{profile_dir}/comprehensive.svg")

# Cleanup
File.rm_rf!(output_dir)

IO.puts("\n=== Profiling Complete ===\n")
IO.puts("Flame graphs have been generated in: #{profile_dir}")
IO.puts("\nTo view the flame graphs:")
IO.puts("  1. Open the .svg files in your browser")
IO.puts("  2. Click on stack frames to zoom in")
IO.puts("  3. Search for specific functions using the search box")
IO.puts("  4. Width of frames indicates time spent in that function\n")
IO.puts("Look for:")
IO.puts("  - Wide frames (functions taking significant time)")
IO.puts("  - Repeated patterns (opportunities for optimization)")
IO.puts("  - Unexpected function calls (potential inefficiencies)\n")
