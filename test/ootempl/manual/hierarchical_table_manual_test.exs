defmodule Ootempl.Manual.HierarchicalTableManualTest do
  @moduledoc """
  Manual verification tests for hierarchical table functionality.

  These tests generate .docx files that should be opened in Microsoft Word
  to verify correct rendering. Run with:

      mix test test/ootempl/manual/hierarchical_table_manual_test.exs

  Output files are saved to test/fixtures/manual/ and are NOT cleaned up
  automatically so you can inspect them.
  """

  use ExUnit.Case

  @output_dir "test/fixtures/manual"

  setup_all do
    File.mkdir_p!(@output_dir)
    :ok
  end

  describe "hierarchical table manual verification" do
    test "revenue report with nested line items" do
      # Create the template
      template_path = Path.join(@output_dir, "revenue_template.docx")
      output_path = Path.join(@output_dir, "revenue_report_output.docx")

      create_revenue_report_template(template_path)

      # Render with realistic data
      data = %{
        "report_title" => "Q4 2025 Revenue Summary",
        "report_date" => "January 15, 2026",
        "prepared_by" => "Finance Department",
        "revcode_data" => [
          %{
            "revcode" => "0250",
            "description" => "Pharmacy",
            "total_amount" => "$45,230.00",
            "subtotal" => "$45,230.00",
            "children" => [
              %{"child_desc" => "PCO: 12345 - Generic Drug A (30-day supply)", "cost" => "$12,500.00"},
              %{"child_desc" => "PCO: 12346 - Brand Drug B (90-day supply)", "cost" => "$18,750.00"},
              %{"child_desc" => "PCO: 12347 - Specialty Drug C (injection)", "cost" => "$8,980.00"},
              %{"child_desc" => "PCO: 12348 - OTC Medications", "cost" => "$5,000.00"}
            ]
          },
          %{
            "revcode" => "0300",
            "description" => "Laboratory",
            "total_amount" => "$12,840.00",
            "subtotal" => "$12,840.00",
            "children" => [
              %{"child_desc" => "PCO: 80053 - Comprehensive Metabolic Panel", "cost" => "$2,340.00"},
              %{"child_desc" => "PCO: 85025 - Complete Blood Count", "cost" => "$1,800.00"},
              %{"child_desc" => "PCO: 84443 - Thyroid Panel", "cost" => "$3,200.00"},
              %{"child_desc" => "PCO: 82947 - Glucose Testing", "cost" => "$1,500.00"},
              %{"child_desc" => "PCO: 87086 - Urinalysis Culture", "cost" => "$4,000.00"}
            ]
          },
          %{
            "revcode" => "0450",
            "description" => "Emergency Room",
            "total_amount" => "$28,500.00",
            "subtotal" => "$28,500.00",
            "children" => [
              %{"child_desc" => "PCO: 99285 - Level 5 ER Visit", "cost" => "$15,000.00"},
              %{"child_desc" => "PCO: 99284 - Level 4 ER Visit", "cost" => "$8,500.00"},
              %{"child_desc" => "PCO: 99283 - Level 3 ER Visit", "cost" => "$5,000.00"}
            ]
          },
          %{
            "revcode" => "0120",
            "description" => "Room & Board - Semi-Private",
            "total_amount" => "$32,000.00",
            "subtotal" => "$32,000.00",
            "children" => [
              %{"child_desc" => "PCO: Day 1-3 @ $4,000/day", "cost" => "$12,000.00"},
              %{"child_desc" => "PCO: Day 4-8 @ $4,000/day", "cost" => "$20,000.00"}
            ]
          }
        ],
        "grand_total" => "$118,570.00"
      }

      result = Ootempl.render(template_path, data, output_path)

      assert result == :ok
      assert File.exists?(output_path)

      print_verification_instructions(output_path, """
      REVENUE REPORT VERIFICATION
      ===========================

      Expected Content:
      -----------------
      1. Title: "Q4 2025 Revenue Summary"
      2. Date: "January 15, 2026"
      3. Prepared by: "Finance Department"

      4. Table with 4 revenue code categories:
         - 0250 Pharmacy ($45,230.00) with 4 line items
         - 0300 Laboratory ($12,840.00) with 5 line items
         - 0450 Emergency Room ($28,500.00) with 3 line items
         - 0120 Room & Board ($32,000.00) with 2 line items

      5. Each category should have:
         - Header row with RevCode, Description, Total Amount
         - Indented child rows for each line item
         - Subtotal row at the end

      6. Grand Total: $118,570.00

      What to Check:
      --------------
      [ ] File opens without errors in Word
      [ ] No {{#...}} or {{/...}} markers visible
      [ ] No {{placeholder}} text visible
      [ ] All 4 categories appear with correct data
      [ ] All child items appear under correct parent
      [ ] Subtotals appear after each category's children
      [ ] Table structure is intact (borders, alignment)
      """)
    end

    test "invoice with product categories and items" do
      template_path = Path.join(@output_dir, "invoice_template.docx")
      output_path = Path.join(@output_dir, "invoice_output.docx")

      create_invoice_template(template_path)

      data = %{
        "invoice_number" => "INV-2026-0042",
        "invoice_date" => "January 27, 2026",
        "customer_name" => "Acme Corporation",
        "customer_address" => "123 Business Park Drive, Suite 500",
        "customer_city" => "San Francisco, CA 94102",
        "categories" => [
          %{
            "category_name" => "Software Licenses",
            "category_total" => "$15,000.00",
            "items" => [
              %{"item_name" => "Enterprise Suite - Annual License", "qty" => "5", "unit_price" => "$2,000.00", "line_total" => "$10,000.00"},
              %{"item_name" => "Developer Tools Add-on", "qty" => "10", "unit_price" => "$500.00", "line_total" => "$5,000.00"}
            ]
          },
          %{
            "category_name" => "Professional Services",
            "category_total" => "$8,400.00",
            "items" => [
              %{"item_name" => "Implementation Consulting (hours)", "qty" => "40", "unit_price" => "$150.00", "line_total" => "$6,000.00"},
              %{"item_name" => "Training Session (per session)", "qty" => "4", "unit_price" => "$600.00", "line_total" => "$2,400.00"}
            ]
          },
          %{
            "category_name" => "Hardware",
            "category_total" => "$3,200.00",
            "items" => [
              %{"item_name" => "Security Token (USB)", "qty" => "20", "unit_price" => "$80.00", "line_total" => "$1,600.00"},
              %{"item_name" => "Backup Drive (1TB)", "qty" => "4", "unit_price" => "$400.00", "line_total" => "$1,600.00"}
            ]
          }
        ],
        "subtotal" => "$26,600.00",
        "tax_rate" => "8.5%",
        "tax_amount" => "$2,261.00",
        "grand_total" => "$28,861.00"
      }

      result = Ootempl.render(template_path, data, output_path)

      assert result == :ok
      assert File.exists?(output_path)

      print_verification_instructions(output_path, """
      INVOICE VERIFICATION
      ====================

      Expected Content:
      -----------------
      1. Invoice #: INV-2026-0042
      2. Date: January 27, 2026
      3. Customer: Acme Corporation

      4. Table with 3 product categories:
         - Software Licenses ($15,000.00) with 2 items
         - Professional Services ($8,400.00) with 2 items
         - Hardware ($3,200.00) with 2 items

      5. Each category should show:
         - Category name as header
         - Line items with name, qty, unit price, line total
         - Category subtotal

      6. Footer:
         - Subtotal: $26,600.00
         - Tax (8.5%): $2,261.00
         - Grand Total: $28,861.00

      What to Check:
      --------------
      [ ] File opens without errors in Word
      [ ] No block markers visible
      [ ] All placeholders replaced
      [ ] 3 categories with correct items
      [ ] Quantities and prices correct
      [ ] Math adds up correctly
      """)
    end

    test "empty categories and children edge cases" do
      template_path = Path.join(@output_dir, "edge_case_template.docx")
      output_path = Path.join(@output_dir, "edge_case_output.docx")

      create_revenue_report_template(template_path)

      data = %{
        "report_title" => "Edge Case Test Report",
        "report_date" => "January 27, 2026",
        "prepared_by" => "QA Team",
        "revcode_data" => [
          %{
            "revcode" => "0100",
            "description" => "Category With Children",
            "total_amount" => "$500.00",
            "subtotal" => "$500.00",
            "children" => [
              %{"child_desc" => "Single Child Item", "cost" => "$500.00"}
            ]
          },
          %{
            "revcode" => "0200",
            "description" => "Category With No Children",
            "total_amount" => "$0.00",
            "subtotal" => "$0.00",
            "children" => []
          },
          %{
            "revcode" => "0300",
            "description" => "Category With Many Children",
            "total_amount" => "$1,000.00",
            "subtotal" => "$1,000.00",
            "children" => [
              %{"child_desc" => "Child 1", "cost" => "$100.00"},
              %{"child_desc" => "Child 2", "cost" => "$100.00"},
              %{"child_desc" => "Child 3", "cost" => "$100.00"},
              %{"child_desc" => "Child 4", "cost" => "$100.00"},
              %{"child_desc" => "Child 5", "cost" => "$100.00"},
              %{"child_desc" => "Child 6", "cost" => "$100.00"},
              %{"child_desc" => "Child 7", "cost" => "$100.00"},
              %{"child_desc" => "Child 8", "cost" => "$100.00"},
              %{"child_desc" => "Child 9", "cost" => "$100.00"},
              %{"child_desc" => "Child 10", "cost" => "$100.00"}
            ]
          }
        ],
        "grand_total" => "$1,500.00"
      }

      result = Ootempl.render(template_path, data, output_path)

      assert result == :ok
      assert File.exists?(output_path)

      print_verification_instructions(output_path, """
      EDGE CASE VERIFICATION
      ======================

      Expected Content:
      -----------------
      1. Title: "Edge Case Test Report"

      2. Three categories:
         - 0100: "Category With Children" - 1 child item
         - 0200: "Category With No Children" - NO child items (just header and subtotal)
         - 0300: "Category With Many Children" - 10 child items

      What to Check:
      --------------
      [ ] Category 0100 shows its single child
      [ ] Category 0200 shows header and subtotal but NO children rows
      [ ] Category 0300 shows all 10 children
      [ ] Each category still has its subtotal row
      [ ] Table structure is maintained
      """)
    end

    test "simple single-level block table" do
      template_path = Path.join(@output_dir, "simple_block_template.docx")
      output_path = Path.join(@output_dir, "simple_block_output.docx")

      create_simple_list_template(template_path)

      data = %{
        "list_title" => "Shopping List",
        "items" => [
          %{"name" => "Apples", "quantity" => "6", "price" => "$3.00"},
          %{"name" => "Bread", "quantity" => "2", "price" => "$5.50"},
          %{"name" => "Milk", "quantity" => "1", "price" => "$4.25"},
          %{"name" => "Eggs", "quantity" => "12", "price" => "$6.00"},
          %{"name" => "Cheese", "quantity" => "1", "price" => "$8.99"}
        ],
        "total" => "$27.74"
      }

      result = Ootempl.render(template_path, data, output_path)

      assert result == :ok
      assert File.exists?(output_path)

      print_verification_instructions(output_path, """
      SIMPLE LIST VERIFICATION
      ========================

      Expected Content:
      -----------------
      1. Title: "Shopping List"

      2. Table with header row: Item | Quantity | Price

      3. Five items:
         - Apples (6) - $3.00
         - Bread (2) - $5.50
         - Milk (1) - $4.25
         - Eggs (12) - $6.00
         - Cheese (1) - $8.99

      4. Total: $27.74

      What to Check:
      --------------
      [ ] Header row "Item | Quantity | Price" is preserved
      [ ] All 5 items appear in the table
      [ ] Block markers {{#items}} and {{/items}} are NOT visible
      [ ] Total row appears after the items
      """)
    end
  end

  # Template creation helpers

  defp create_revenue_report_template(output_path) do
    file_map = %{
      "[Content_Types].xml" => content_types_xml(),
      "_rels/.rels" => rels_xml(),
      "word/document.xml" => revenue_report_document_xml(),
      "word/_rels/document.xml.rels" => document_rels_xml()
    }

    :ok = Ootempl.Archive.create(file_map, output_path)
  end

  defp create_invoice_template(output_path) do
    file_map = %{
      "[Content_Types].xml" => content_types_xml(),
      "_rels/.rels" => rels_xml(),
      "word/document.xml" => invoice_document_xml(),
      "word/_rels/document.xml.rels" => document_rels_xml()
    }

    :ok = Ootempl.Archive.create(file_map, output_path)
  end

  defp create_simple_list_template(output_path) do
    file_map = %{
      "[Content_Types].xml" => content_types_xml(),
      "_rels/.rels" => rels_xml(),
      "word/document.xml" => simple_list_document_xml(),
      "word/_rels/document.xml.rels" => document_rels_xml()
    }

    :ok = Ootempl.Archive.create(file_map, output_path)
  end

  defp content_types_xml do
    """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
      <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
      <Default Extension="xml" ContentType="application/xml"/>
      <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
    </Types>
    """
  end

  defp rels_xml do
    """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
    </Relationships>
    """
  end

  defp document_rels_xml do
    """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    </Relationships>
    """
  end

  defp revenue_report_document_xml do
    """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
      <w:body>
        <w:p>
          <w:pPr><w:jc w:val="center"/></w:pPr>
          <w:r><w:rPr><w:b/><w:sz w:val="32"/></w:rPr><w:t>{{report_title}}</w:t></w:r>
        </w:p>
        <w:p>
          <w:r><w:t>Date: {{report_date}}</w:t></w:r>
        </w:p>
        <w:p>
          <w:r><w:t>Prepared by: {{prepared_by}}</w:t></w:r>
        </w:p>
        <w:p><w:r><w:t></w:t></w:r></w:p>
        <w:tbl>
          <w:tblPr>
            <w:tblBorders>
              <w:top w:val="single" w:sz="4"/>
              <w:left w:val="single" w:sz="4"/>
              <w:bottom w:val="single" w:sz="4"/>
              <w:right w:val="single" w:sz="4"/>
              <w:insideH w:val="single" w:sz="4"/>
              <w:insideV w:val="single" w:sz="4"/>
            </w:tblBorders>
          </w:tblPr>
          <w:tr>
            <w:tc><w:p><w:r><w:rPr><w:b/></w:rPr><w:t>RevCode</w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:r><w:rPr><w:b/></w:rPr><w:t>Description</w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:r><w:rPr><w:b/></w:rPr><w:t>Amount</w:t></w:r></w:p></w:tc>
          </w:tr>
          <w:tr>
            <w:tc><w:p><w:r><w:t>{{#revcode_data}}</w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:r><w:t></w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:r><w:t></w:t></w:r></w:p></w:tc>
          </w:tr>
          <w:tr>
            <w:tc><w:p><w:r><w:rPr><w:b/></w:rPr><w:t>{{revcode}}</w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:r><w:rPr><w:b/></w:rPr><w:t>{{description}}</w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:r><w:rPr><w:b/></w:rPr><w:t>{{total_amount}}</w:t></w:r></w:p></w:tc>
          </w:tr>
          <w:tr>
            <w:tc><w:p><w:r><w:t>{{#children}}</w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:r><w:t></w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:r><w:t></w:t></w:r></w:p></w:tc>
          </w:tr>
          <w:tr>
            <w:tc><w:p><w:r><w:t></w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:r><w:t>{{child_desc}}</w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:r><w:t>{{cost}}</w:t></w:r></w:p></w:tc>
          </w:tr>
          <w:tr>
            <w:tc><w:p><w:r><w:t>{{/children}}</w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:r><w:t></w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:r><w:t></w:t></w:r></w:p></w:tc>
          </w:tr>
          <w:tr>
            <w:tc><w:p><w:r><w:t></w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:pPr><w:jc w:val="right"/></w:pPr><w:r><w:rPr><w:i/></w:rPr><w:t>Subtotal:</w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:r><w:rPr><w:i/></w:rPr><w:t>{{subtotal}}</w:t></w:r></w:p></w:tc>
          </w:tr>
          <w:tr>
            <w:tc><w:p><w:r><w:t>{{/revcode_data}}</w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:r><w:t></w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:r><w:t></w:t></w:r></w:p></w:tc>
          </w:tr>
          <w:tr>
            <w:tc><w:p><w:r><w:t></w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:pPr><w:jc w:val="right"/></w:pPr><w:r><w:rPr><w:b/></w:rPr><w:t>GRAND TOTAL:</w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:r><w:rPr><w:b/></w:rPr><w:t>{{grand_total}}</w:t></w:r></w:p></w:tc>
          </w:tr>
        </w:tbl>
      </w:body>
    </w:document>
    """
  end

  defp invoice_document_xml do
    """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
      <w:body>
        <w:p>
          <w:pPr><w:jc w:val="center"/></w:pPr>
          <w:r><w:rPr><w:b/><w:sz w:val="36"/></w:rPr><w:t>INVOICE</w:t></w:r>
        </w:p>
        <w:p><w:r><w:t></w:t></w:r></w:p>
        <w:p>
          <w:r><w:rPr><w:b/></w:rPr><w:t>Invoice #: </w:t></w:r>
          <w:r><w:t>{{invoice_number}}</w:t></w:r>
        </w:p>
        <w:p>
          <w:r><w:rPr><w:b/></w:rPr><w:t>Date: </w:t></w:r>
          <w:r><w:t>{{invoice_date}}</w:t></w:r>
        </w:p>
        <w:p><w:r><w:t></w:t></w:r></w:p>
        <w:p>
          <w:r><w:rPr><w:b/></w:rPr><w:t>Bill To:</w:t></w:r>
        </w:p>
        <w:p><w:r><w:t>{{customer_name}}</w:t></w:r></w:p>
        <w:p><w:r><w:t>{{customer_address}}</w:t></w:r></w:p>
        <w:p><w:r><w:t>{{customer_city}}</w:t></w:r></w:p>
        <w:p><w:r><w:t></w:t></w:r></w:p>
        <w:tbl>
          <w:tblPr>
            <w:tblBorders>
              <w:top w:val="single" w:sz="4"/>
              <w:left w:val="single" w:sz="4"/>
              <w:bottom w:val="single" w:sz="4"/>
              <w:right w:val="single" w:sz="4"/>
              <w:insideH w:val="single" w:sz="4"/>
              <w:insideV w:val="single" w:sz="4"/>
            </w:tblBorders>
          </w:tblPr>
          <w:tr>
            <w:tc><w:p><w:r><w:rPr><w:b/></w:rPr><w:t>Item</w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:r><w:rPr><w:b/></w:rPr><w:t>Qty</w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:r><w:rPr><w:b/></w:rPr><w:t>Unit Price</w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:r><w:rPr><w:b/></w:rPr><w:t>Total</w:t></w:r></w:p></w:tc>
          </w:tr>
          <w:tr>
            <w:tc><w:p><w:r><w:t>{{#categories}}</w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:r><w:t></w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:r><w:t></w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:r><w:t></w:t></w:r></w:p></w:tc>
          </w:tr>
          <w:tr>
            <w:tc><w:p><w:r><w:rPr><w:b/><w:shd w:val="clear" w:fill="E0E0E0"/></w:rPr><w:t>{{category_name}}</w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:r><w:t></w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:r><w:t></w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:r><w:rPr><w:b/></w:rPr><w:t>{{category_total}}</w:t></w:r></w:p></w:tc>
          </w:tr>
          <w:tr>
            <w:tc><w:p><w:r><w:t>{{#items}}</w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:r><w:t></w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:r><w:t></w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:r><w:t></w:t></w:r></w:p></w:tc>
          </w:tr>
          <w:tr>
            <w:tc><w:p><w:r><w:t>  {{item_name}}</w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:pPr><w:jc w:val="center"/></w:pPr><w:r><w:t>{{qty}}</w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:pPr><w:jc w:val="right"/></w:pPr><w:r><w:t>{{unit_price}}</w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:pPr><w:jc w:val="right"/></w:pPr><w:r><w:t>{{line_total}}</w:t></w:r></w:p></w:tc>
          </w:tr>
          <w:tr>
            <w:tc><w:p><w:r><w:t>{{/items}}</w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:r><w:t></w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:r><w:t></w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:r><w:t></w:t></w:r></w:p></w:tc>
          </w:tr>
          <w:tr>
            <w:tc><w:p><w:r><w:t>{{/categories}}</w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:r><w:t></w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:r><w:t></w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:r><w:t></w:t></w:r></w:p></w:tc>
          </w:tr>
          <w:tr>
            <w:tc><w:p><w:r><w:t></w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:r><w:t></w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:pPr><w:jc w:val="right"/></w:pPr><w:r><w:t>Subtotal:</w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:pPr><w:jc w:val="right"/></w:pPr><w:r><w:t>{{subtotal}}</w:t></w:r></w:p></w:tc>
          </w:tr>
          <w:tr>
            <w:tc><w:p><w:r><w:t></w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:r><w:t></w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:pPr><w:jc w:val="right"/></w:pPr><w:r><w:t>Tax ({{tax_rate}}):</w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:pPr><w:jc w:val="right"/></w:pPr><w:r><w:t>{{tax_amount}}</w:t></w:r></w:p></w:tc>
          </w:tr>
          <w:tr>
            <w:tc><w:p><w:r><w:t></w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:r><w:t></w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:pPr><w:jc w:val="right"/></w:pPr><w:r><w:rPr><w:b/></w:rPr><w:t>TOTAL:</w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:pPr><w:jc w:val="right"/></w:pPr><w:r><w:rPr><w:b/></w:rPr><w:t>{{grand_total}}</w:t></w:r></w:p></w:tc>
          </w:tr>
        </w:tbl>
      </w:body>
    </w:document>
    """
  end

  defp simple_list_document_xml do
    """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
      <w:body>
        <w:p>
          <w:pPr><w:jc w:val="center"/></w:pPr>
          <w:r><w:rPr><w:b/><w:sz w:val="28"/></w:rPr><w:t>{{list_title}}</w:t></w:r>
        </w:p>
        <w:p><w:r><w:t></w:t></w:r></w:p>
        <w:tbl>
          <w:tblPr>
            <w:tblBorders>
              <w:top w:val="single" w:sz="4"/>
              <w:left w:val="single" w:sz="4"/>
              <w:bottom w:val="single" w:sz="4"/>
              <w:right w:val="single" w:sz="4"/>
              <w:insideH w:val="single" w:sz="4"/>
              <w:insideV w:val="single" w:sz="4"/>
            </w:tblBorders>
          </w:tblPr>
          <w:tr>
            <w:tc><w:p><w:r><w:rPr><w:b/></w:rPr><w:t>Item</w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:r><w:rPr><w:b/></w:rPr><w:t>Quantity</w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:r><w:rPr><w:b/></w:rPr><w:t>Price</w:t></w:r></w:p></w:tc>
          </w:tr>
          <w:tr>
            <w:tc><w:p><w:r><w:t>{{#items}}</w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:r><w:t></w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:r><w:t></w:t></w:r></w:p></w:tc>
          </w:tr>
          <w:tr>
            <w:tc><w:p><w:r><w:t>{{name}}</w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:pPr><w:jc w:val="center"/></w:pPr><w:r><w:t>{{quantity}}</w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:pPr><w:jc w:val="right"/></w:pPr><w:r><w:t>{{price}}</w:t></w:r></w:p></w:tc>
          </w:tr>
          <w:tr>
            <w:tc><w:p><w:r><w:t>{{/items}}</w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:r><w:t></w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:r><w:t></w:t></w:r></w:p></w:tc>
          </w:tr>
          <w:tr>
            <w:tc><w:p><w:r><w:t></w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:pPr><w:jc w:val="right"/></w:pPr><w:r><w:rPr><w:b/></w:rPr><w:t>Total:</w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:pPr><w:jc w:val="right"/></w:pPr><w:r><w:rPr><w:b/></w:rPr><w:t>{{total}}</w:t></w:r></w:p></w:tc>
          </w:tr>
        </w:tbl>
      </w:body>
    </w:document>
    """
  end

  defp print_verification_instructions(output_path, instructions) do
    IO.puts("""

    ================================================================================
    OUTPUT FILE GENERATED
    ================================================================================
    Path: #{Path.expand(output_path)}

    #{instructions}
    ================================================================================
    """)
  end
end
