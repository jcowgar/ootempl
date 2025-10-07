# Benchmarks for Ootempl document rendering performance
#
# Run with: mix run benchmarks/render_benchmarks.exs

# Setup output directory for benchmark runs
output_dir = "benchmarks/output"
File.mkdir_p!(output_dir)

# Helper function to generate table row data
defmodule BenchmarkHelpers do
  def generate_table_data(num_rows) do
    Enum.map(1..num_rows, fn i ->
      %{
        "id" => Integer.to_string(5000 + i),
        "amount" => Float.to_string(:rand.uniform(1000) + 0.50)
      }
    end)
  end

  def generate_order_data(num_rows) do
    products = ["Widget", "Gadget", "Sprocket", "Doodad", "Gizmo", "Thingamajig"]

    Enum.map(1..num_rows, fn i ->
      %{
        "id" => Integer.to_string(100 + i),
        "product" => Enum.at(products, rem(i, length(products))),
        "qty" => Integer.to_string(:rand.uniform(20)),
        "price" => Float.to_string(:rand.uniform(100) + 0.99)
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

  def generate_multi_section_data(num_sections) do
    base_data = generate_simple_data()

    sections =
      Enum.map(1..num_sections, fn i ->
        %{
          "title" => "Section #{i}",
          "content" => "This is the content for section #{i}. " <> String.duplicate("Lorem ipsum dolor sit amet. ", 50)
        }
      end)

    Map.put(base_data, "sections", sections)
  end
end

# Benchmark scenarios
Benchee.run(
  %{
    "single-page simple placeholders" => fn ->
      data = BenchmarkHelpers.generate_simple_data()
      output = "#{output_dir}/simple_#{:erlang.unique_integer([:positive])}.docx"
      Ootempl.render("test/fixtures/Simple Placeholders.docx", data, output)
      File.rm(output)
    end,
    "table with 10 rows" => fn ->
      data = %{
        "title" => "Invoice Report",
        "date" => "October 7, 2025",
        "claims" => BenchmarkHelpers.generate_table_data(10),
        "total" => "12,345.67"
      }

      output = "#{output_dir}/table_10_#{:erlang.unique_integer([:positive])}.docx"
      Ootempl.render("test/fixtures/table_simple.docx", data, output)
      File.rm(output)
    end,
    "table with 25 rows" => fn ->
      data = %{
        "title" => "Invoice Report",
        "date" => "October 7, 2025",
        "claims" => BenchmarkHelpers.generate_table_data(25),
        "total" => "12,345.67"
      }

      output = "#{output_dir}/table_25_#{:erlang.unique_integer([:positive])}.docx"
      Ootempl.render("test/fixtures/table_simple.docx", data, output)
      File.rm(output)
    end,
    "table with 50 rows" => fn ->
      data = %{
        "title" => "Invoice Report",
        "date" => "October 7, 2025",
        "claims" => BenchmarkHelpers.generate_table_data(50),
        "total" => "12,345.67"
      }

      output = "#{output_dir}/table_50_#{:erlang.unique_integer([:positive])}.docx"
      Ootempl.render("test/fixtures/table_simple.docx", data, output)
      File.rm(output)
    end,
    "multi-row table with 15 items" => fn ->
      data = %{
        "orders" => BenchmarkHelpers.generate_order_data(15)
      }

      output = "#{output_dir}/multirow_15_#{:erlang.unique_integer([:positive])}.docx"
      Ootempl.render("test/fixtures/table_multirow.docx", data, output)
      File.rm(output)
    end,
    "multi-row table with 30 items" => fn ->
      data = %{
        "orders" => BenchmarkHelpers.generate_order_data(30)
      }

      output = "#{output_dir}/multirow_30_#{:erlang.unique_integer([:positive])}.docx"
      Ootempl.render("test/fixtures/table_multirow.docx", data, output)
      File.rm(output)
    end,
    "comprehensive template" => fn ->
      data = %{
        "document_title" => "Comprehensive Document",
        "company_name" => "Acme Corp",
        "footnote_ref" => "Reference 1",
        "endnote_text" => "Additional notes",
        "person" => %{"first_name" => "John Doe"},
        "date" => "2025-10-07"
      }

      output = "#{output_dir}/comprehensive_#{:erlang.unique_integer([:positive])}.docx"
      Ootempl.render("test/fixtures/comprehensive_template.docx", data, output)
      File.rm(output)
    end
  },
  time: 10,
  memory_time: 2,
  warmup: 2,
  formatters: [
    {Benchee.Formatters.Console, extended_statistics: true}
  ]
)

# Cleanup
File.rm_rf!(output_dir)
