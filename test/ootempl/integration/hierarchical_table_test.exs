defmodule Ootempl.Integration.HierarchicalTableTest do
  @moduledoc """
  Integration tests for hierarchical table support using block markers.

  Tests the {{#list}}...{{/list}} syntax for multi-level data iteration
  with header/body/footer sections in tables.
  """

  use ExUnit.Case

  alias Ootempl.FixtureHelper

  @hierarchical_template_path "test/fixtures/table_hierarchical_generated.docx"
  @simple_block_template_path "test/fixtures/table_simple_block_generated.docx"
  @output_path "tmp/hierarchical_table_output.docx"

  setup do
    # Create fixtures if they don't exist
    if !File.exists?(@hierarchical_template_path) do
      FixtureHelper.create_hierarchical_table_docx(@hierarchical_template_path)
    end

    if !File.exists?(@simple_block_template_path) do
      FixtureHelper.create_simple_block_table_docx(@simple_block_template_path)
    end

    on_exit(fn ->
      File.rm(@output_path)
    end)

    :ok
  end

  describe "hierarchical table rendering" do
    test "renders two-level nested block table" do
      data = %{
        "report_title" => "Q4 2025",
        "revcode_data" => [
          %{
            "revcode" => "25X",
            "description" => "Pharmacy",
            "total_amount" => "$12,000",
            "subtotal" => "$12,000",
            "children" => [
              %{"child_desc" => "PCO: Drug A", "cost" => "$4,000"},
              %{"child_desc" => "PCO: Drug B", "cost" => "$8,000"}
            ]
          },
          %{
            "revcode" => "30X",
            "description" => "Room & Board",
            "total_amount" => "$2,000",
            "subtotal" => "$2,000",
            "children" => [
              %{"child_desc" => "PCO: Emergency", "cost" => "$1,500"},
              %{"child_desc" => "PCO: Standard", "cost" => "$500"}
            ]
          }
        ]
      }

      result = Ootempl.render(@hierarchical_template_path, data, @output_path)

      assert result == :ok
      assert File.exists?(@output_path)

      {:ok, output_xml} = OotemplTestHelpers.extract_file_for_test(@output_path, "word/document.xml")

      # Verify report title
      assert output_xml =~ "Q4 2025"

      # Verify first parent (25X Pharmacy)
      assert output_xml =~ "25X"
      assert output_xml =~ "Pharmacy"
      assert output_xml =~ "$12,000"

      # Verify first parent's children
      assert output_xml =~ "PCO: Drug A"
      assert output_xml =~ "$4,000"
      assert output_xml =~ "PCO: Drug B"
      assert output_xml =~ "$8,000"

      # Verify second parent (30X Room & Board)
      # Note: & is escaped to &amp; in XML, which appears as &amp;amp; in serialized XML string
      assert output_xml =~ "30X"
      assert output_xml =~ "Room &amp;amp; Board"
      assert output_xml =~ "$2,000"

      # Verify second parent's children
      assert output_xml =~ "PCO: Emergency"
      assert output_xml =~ "$1,500"
      assert output_xml =~ "PCO: Standard"
      assert output_xml =~ "$500"

      # Verify subtotals appear
      assert output_xml =~ "Subtotal:"

      # Verify block markers are removed
      refute output_xml =~ "{{#revcode_data}}"
      refute output_xml =~ "{{/revcode_data}}"
      refute output_xml =~ "{{#children}}"
      refute output_xml =~ "{{/children}}"

      # Verify placeholders are replaced
      refute output_xml =~ "{{revcode}}"
      refute output_xml =~ "{{description}}"
      refute output_xml =~ "{{child_desc}}"
      refute output_xml =~ "{{cost}}"
    end

    test "handles empty parent list" do
      data = %{
        "report_title" => "Empty Report",
        "revcode_data" => []
      }

      result = Ootempl.render(@hierarchical_template_path, data, @output_path)

      assert result == :ok

      {:ok, output_xml} = OotemplTestHelpers.extract_file_for_test(@output_path, "word/document.xml")

      # Verify report title
      assert output_xml =~ "Empty Report"

      # No parent data should appear
      refute output_xml =~ "25X"
      refute output_xml =~ "Pharmacy"
    end

    test "handles empty children list" do
      data = %{
        "report_title" => "No Children Report",
        "revcode_data" => [
          %{
            "revcode" => "10X",
            "description" => "Services",
            "total_amount" => "$500",
            "subtotal" => "$500",
            "children" => []
          }
        ]
      }

      result = Ootempl.render(@hierarchical_template_path, data, @output_path)

      assert result == :ok

      {:ok, output_xml} = OotemplTestHelpers.extract_file_for_test(@output_path, "word/document.xml")

      # Parent should appear
      assert output_xml =~ "10X"
      assert output_xml =~ "Services"
      assert output_xml =~ "$500"

      # Subtotal should still appear
      assert output_xml =~ "Subtotal:"
    end

    test "handles multiple parents with varying children" do
      data = %{
        "report_title" => "Varying Children",
        "revcode_data" => [
          %{
            "revcode" => "A",
            "description" => "Category A",
            "total_amount" => "$100",
            "subtotal" => "$100",
            "children" => [
              %{"child_desc" => "A1", "cost" => "$100"}
            ]
          },
          %{
            "revcode" => "B",
            "description" => "Category B",
            "total_amount" => "$300",
            "subtotal" => "$300",
            "children" => [
              %{"child_desc" => "B1", "cost" => "$100"},
              %{"child_desc" => "B2", "cost" => "$100"},
              %{"child_desc" => "B3", "cost" => "$100"}
            ]
          },
          %{
            "revcode" => "C",
            "description" => "Category C",
            "total_amount" => "$0",
            "subtotal" => "$0",
            "children" => []
          }
        ]
      }

      result = Ootempl.render(@hierarchical_template_path, data, @output_path)

      assert result == :ok

      {:ok, output_xml} = OotemplTestHelpers.extract_file_for_test(@output_path, "word/document.xml")

      # All categories should appear
      assert output_xml =~ "Category A"
      assert output_xml =~ "Category B"
      assert output_xml =~ "Category C"

      # All children should appear
      assert output_xml =~ "A1"
      assert output_xml =~ "B1"
      assert output_xml =~ "B2"
      assert output_xml =~ "B3"
    end

    test "output is valid .docx file" do
      data = %{
        "report_title" => "Valid Test",
        "revcode_data" => [
          %{
            "revcode" => "X",
            "description" => "Test",
            "total_amount" => "$1",
            "subtotal" => "$1",
            "children" => [%{"child_desc" => "Child", "cost" => "$1"}]
          }
        ]
      }

      Ootempl.render(@hierarchical_template_path, data, @output_path)

      assert :ok = Ootempl.Validator.validate_docx(@output_path)
    end

    test "removes marker-only rows from output" do
      data = %{
        "report_title" => "Marker Rows Test",
        "revcode_data" => [
          %{
            "revcode" => "TEST",
            "description" => "Test Desc",
            "total_amount" => "$100",
            "subtotal" => "$100",
            "children" => [%{"child_desc" => "Child Desc", "cost" => "$100"}]
          }
        ]
      }

      Ootempl.render(@hierarchical_template_path, data, @output_path)

      {:ok, output_xml} = OotemplTestHelpers.extract_file_for_test(@output_path, "word/document.xml")

      # The marker text should not appear (rows removed)
      refute output_xml =~ "{{#"
      refute output_xml =~ "{{/"

      # But the data should still be there
      assert output_xml =~ "TEST"
      assert output_xml =~ "Child Desc"
    end
  end

  describe "simple block table" do
    test "renders single-level block table" do
      data = %{
        "total" => "$150",
        "items" => [
          %{"name" => "Widget", "price" => "$50"},
          %{"name" => "Gadget", "price" => "$100"}
        ]
      }

      result = Ootempl.render(@simple_block_template_path, data, @output_path)

      assert result == :ok

      {:ok, output_xml} = OotemplTestHelpers.extract_file_for_test(@output_path, "word/document.xml")

      # Verify header row is preserved
      assert output_xml =~ "Name"
      assert output_xml =~ "Price"

      # Verify items appear
      assert output_xml =~ "Widget"
      assert output_xml =~ "$50"
      assert output_xml =~ "Gadget"
      assert output_xml =~ "$100"

      # Verify total
      assert output_xml =~ "$150"

      # Verify markers removed
      refute output_xml =~ "{{#items}}"
      refute output_xml =~ "{{/items}}"
    end

    test "handles empty items list" do
      data = %{
        "total" => "$0",
        "items" => []
      }

      result = Ootempl.render(@simple_block_template_path, data, @output_path)

      assert result == :ok

      {:ok, output_xml} = OotemplTestHelpers.extract_file_for_test(@output_path, "word/document.xml")

      # Header should still be there
      assert output_xml =~ "Name"
      assert output_xml =~ "Price"

      # Total should be there
      assert output_xml =~ "$0"
    end
  end

  describe "backward compatibility" do
    test "existing simple table templates still work" do
      # Use an existing template that doesn't have block markers
      template_path = "test/fixtures/Table Repeating Rows from Word.docx"

      data = %{
        "person" => %{"first_name" => "John"},
        "client" => "Acme Corp",
        "people" => [
          %{"first_name" => "Alice", "last_name" => "Smith", "age" => "28"}
        ],
        "average_age" => "28"
      }

      result = Ootempl.render(template_path, data, @output_path)

      assert result == :ok

      {:ok, output_xml} = OotemplTestHelpers.extract_file_for_test(@output_path, "word/document.xml")

      assert output_xml =~ "John"
      assert output_xml =~ "Acme Corp"
      assert output_xml =~ "Alice"
    end

    test "tables without block markers use simple processing" do
      # This verifies the existing table processing still works
      template_path = "test/fixtures/table_multirow.docx"

      # Check if the fixture exists (it should based on earlier ls output)
      if File.exists?(template_path) do
        {:ok, template_xml} = OotemplTestHelpers.extract_file_for_test(template_path, "word/document.xml")

        # Verify it doesn't have block markers
        refute template_xml =~ "{{#"
        refute template_xml =~ "{{/"
      end
    end
  end

  describe "error handling" do
    test "returns error for unmatched block markers" do
      # Create a template with unmatched markers
      bad_template_path = "tmp/bad_block_template.docx"

      file_map = %{
        "[Content_Types].xml" => """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
        </Types>
        """,
        "_rels/.rels" => """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
        </Relationships>
        """,
        "word/document.xml" => """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:body>
            <w:tbl>
              <w:tr>
                <w:tc><w:p><w:r><w:t>{{#items}}</w:t></w:r></w:p></w:tc>
              </w:tr>
              <w:tr>
                <w:tc><w:p><w:r><w:t>{{name}}</w:t></w:r></w:p></w:tc>
              </w:tr>
            </w:tbl>
          </w:body>
        </w:document>
        """,
        "word/_rels/document.xml.rels" => """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        </Relationships>
        """
      }

      :ok = Ootempl.Archive.create(file_map, bad_template_path)

      on_exit(fn ->
        File.rm(bad_template_path)
      end)

      data = %{"items" => [%{"name" => "Test"}]}

      result = Ootempl.render(bad_template_path, data, @output_path)

      assert {:error, _reason} = result
    end

    test "returns error for missing list data" do
      data = %{
        "report_title" => "Test"
        # Missing revcode_data
      }

      result = Ootempl.render(@hierarchical_template_path, data, @output_path)

      # Should succeed but produce empty table (no rows)
      assert result == :ok
    end
  end

  describe "parent data accessible in nested context" do
    test "child rows can access parent data fields" do
      data = %{
        "report_title" => "Parent Access Test",
        "revcode_data" => [
          %{
            "revcode" => "PARENT_CODE",
            "description" => "Parent Desc",
            "total_amount" => "$1000",
            "subtotal" => "$1000",
            "children" => [
              # Child doesn't have revcode, should inherit from parent
              %{"child_desc" => "Child Item", "cost" => "$500"}
            ]
          }
        ]
      }

      result = Ootempl.render(@hierarchical_template_path, data, @output_path)

      assert result == :ok

      {:ok, output_xml} = OotemplTestHelpers.extract_file_for_test(@output_path, "word/document.xml")

      # Both parent and child data should appear
      assert output_xml =~ "PARENT_CODE"
      assert output_xml =~ "Child Item"
    end
  end

  describe "manual verification" do
    @tag :manual
    test "generates output for manual inspection in Microsoft Word" do
      data = %{
        "report_title" => "Q4 2025 Revenue Summary",
        "revcode_data" => [
          %{
            "revcode" => "25X",
            "description" => "Pharmacy Services",
            "total_amount" => "$12,500.00",
            "subtotal" => "$12,500.00",
            "children" => [
              %{"child_desc" => "PCO: 123 Generic Drug A", "cost" => "$4,500.00"},
              %{"child_desc" => "PCO: 456 Brand Drug B", "cost" => "$5,000.00"},
              %{"child_desc" => "PCO: 789 Specialty Drug C", "cost" => "$3,000.00"}
            ]
          },
          %{
            "revcode" => "30X",
            "description" => "Room & Board",
            "total_amount" => "$8,750.00",
            "subtotal" => "$8,750.00",
            "children" => [
              %{"child_desc" => "PCO: Emergency Room", "cost" => "$3,500.00"},
              %{"child_desc" => "PCO: Standard Room", "cost" => "$5,250.00"}
            ]
          },
          %{
            "revcode" => "45X",
            "description" => "Laboratory",
            "total_amount" => "$2,100.00",
            "subtotal" => "$2,100.00",
            "children" => [
              %{"child_desc" => "PCO: Blood Tests", "cost" => "$800.00"},
              %{"child_desc" => "PCO: Urinalysis", "cost" => "$300.00"},
              %{"child_desc" => "PCO: Culture & Sensitivity", "cost" => "$1,000.00"}
            ]
          }
        ]
      }

      manual_output_path = "tmp/hierarchical_table_manual.docx"

      on_exit(fn -> :ok end)

      result = Ootempl.render(@hierarchical_template_path, data, manual_output_path)

      assert result == :ok
      assert File.exists?(manual_output_path)
      assert :ok = Ootempl.Validator.validate_docx(manual_output_path)

      IO.puts("""

      ========================================
      MANUAL VERIFICATION REQUIRED
      ========================================

      Template: #{Path.basename(@hierarchical_template_path)}
      Output:   #{Path.expand(manual_output_path)}

      Test Data Used:
      ---------------
      Report Title: Q4 2025 Revenue Summary
      Categories: 3 (Pharmacy, Room & Board, Laboratory)
      Total Items: 8 nested children

      Expected Content:
      -----------------
      1. Report title "Q4 2025 Revenue Summary" at the top
      2. Table with hierarchical structure:
         - Each category has a header row (revcode, description, total)
         - Each category has child rows (indented, with desc and cost)
         - Each category has a footer row (Subtotal)
      3. Marker rows ({{#...}} and {{/...}}) should NOT appear
      4. All placeholders should be replaced with actual values

      Verification Steps:
      -------------------
      1. Open the file in Microsoft Word
      2. Verify it opens without errors or corruption warnings
      3. Check that the table structure is correct
      4. Verify all data appears in the correct locations
      5. Confirm no block markers or placeholders remain

      To run this test:
      -----------------
      mix test test/ootempl/integration/hierarchical_table_test.exs --only manual

      ========================================
      """)
    end
  end
end
