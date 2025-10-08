#!/usr/bin/env elixir

# Script to create static .docx fixture files with conditional markers
# This allows for manual verification in Word and realistic testing

Mix.install([])

defmodule ConditionalFixtureCreator do
  @moduledoc """
  Creates .docx fixture files with conditional markers for testing.
  """

  def create_all do
    create_simple_conditional()
    create_if_else_conditional()
    create_multi_paragraph_conditional()
    create_nested_path_conditional()
    create_multiple_conditionals()
    create_conditional_with_variables()

    IO.puts("✓ All conditional fixture files created successfully!")
  end

  defp create_simple_conditional do
    file_map = %{
      "[Content_Types].xml" => content_types_xml(),
      "_rels/.rels" => rels_xml(),
      "word/document.xml" => """
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:body>
          <w:p>
            <w:r><w:t>This is a document with a simple conditional section.</w:t></w:r>
          </w:p>
          <w:p>
            <w:r><w:t>{{if show_section}}</w:t></w:r>
          </w:p>
          <w:p>
            <w:r><w:t>This content only appears when show_section is true.</w:t></w:r>
          </w:p>
          <w:p>
            <w:r><w:t>{{endif}}</w:t></w:r>
          </w:p>
          <w:p>
            <w:r><w:t>This content always appears.</w:t></w:r>
          </w:p>
        </w:body>
      </w:document>
      """,
      "word/_rels/document.xml.rels" => document_rels_xml()
    }

    create_docx(file_map, "test/fixtures/conditional_simple.docx")
    IO.puts("Created: conditional_simple.docx")
  end

  defp create_if_else_conditional do
    file_map = %{
      "[Content_Types].xml" => content_types_xml(),
      "_rels/.rels" => rels_xml(),
      "word/document.xml" => """
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:body>
          <w:p>
            <w:r><w:t>Account Status Report</w:t></w:r>
          </w:p>
          <w:p>
            <w:r><w:t>{{if is_premium}}</w:t></w:r>
          </w:p>
          <w:p>
            <w:r><w:t>PREMIUM MEMBER: You have access to all features and 24/7 support.</w:t></w:r>
          </w:p>
          <w:p>
            <w:r><w:t>{{else}}</w:t></w:r>
          </w:p>
          <w:p>
            <w:r><w:t>STANDARD MEMBER: Upgrade to premium for exclusive benefits!</w:t></w:r>
          </w:p>
          <w:p>
            <w:r><w:t>{{endif}}</w:t></w:r>
          </w:p>
          <w:p>
            <w:r><w:t>Thank you for being our customer.</w:t></w:r>
          </w:p>
        </w:body>
      </w:document>
      """,
      "word/_rels/document.xml.rels" => document_rels_xml()
    }

    create_docx(file_map, "test/fixtures/conditional_if_else.docx")
    IO.puts("Created: conditional_if_else.docx")
  end

  defp create_multi_paragraph_conditional do
    file_map = %{
      "[Content_Types].xml" => content_types_xml(),
      "_rels/.rels" => rels_xml(),
      "word/document.xml" => """
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:body>
          <w:p>
            <w:r><w:t>Contract Agreement</w:t></w:r>
          </w:p>
          <w:p>
            <w:r><w:t>{{if include_warranty}}</w:t></w:r>
          </w:p>
          <w:p>
            <w:r><w:t>WARRANTY SECTION</w:t></w:r>
          </w:p>
          <w:p>
            <w:r><w:t>This product comes with a 2-year warranty.</w:t></w:r>
          </w:p>
          <w:p>
            <w:r><w:t>The warranty covers manufacturing defects and normal wear.</w:t></w:r>
          </w:p>
          <w:p>
            <w:r><w:t>For warranty claims, please contact support@example.com</w:t></w:r>
          </w:p>
          <w:p>
            <w:r><w:t>{{endif}}</w:t></w:r>
          </w:p>
          <w:p>
            <w:r><w:t>End of Contract</w:t></w:r>
          </w:p>
        </w:body>
      </w:document>
      """,
      "word/_rels/document.xml.rels" => document_rels_xml()
    }

    create_docx(file_map, "test/fixtures/conditional_multi_paragraph.docx")
    IO.puts("Created: conditional_multi_paragraph.docx")
  end

  defp create_nested_path_conditional do
    file_map = %{
      "[Content_Types].xml" => content_types_xml(),
      "_rels/.rels" => rels_xml(),
      "word/document.xml" => """
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:body>
          <w:p>
            <w:r><w:t>Customer Account Summary</w:t></w:r>
          </w:p>
          <w:p>
            <w:r><w:t>{{if customer.active}}</w:t></w:r>
          </w:p>
          <w:p>
            <w:r><w:t>Your account is currently ACTIVE.</w:t></w:r>
          </w:p>
          <w:p>
            <w:r><w:t>{{endif}}</w:t></w:r>
          </w:p>
          <w:p>
            <w:r><w:t>{{if customer.profile.verified}}</w:t></w:r>
          </w:p>
          <w:p>
            <w:r><w:t>Profile Status: VERIFIED</w:t></w:r>
          </w:p>
          <w:p>
            <w:r><w:t>{{endif}}</w:t></w:r>
          </w:p>
        </w:body>
      </w:document>
      """,
      "word/_rels/document.xml.rels" => document_rels_xml()
    }

    create_docx(file_map, "test/fixtures/conditional_nested_path.docx")
    IO.puts("Created: conditional_nested_path.docx")
  end

  defp create_multiple_conditionals do
    file_map = %{
      "[Content_Types].xml" => content_types_xml(),
      "_rels/.rels" => rels_xml(),
      "word/document.xml" => """
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:body>
          <w:p>
            <w:r><w:t>Product Catalog</w:t></w:r>
          </w:p>
          <w:p>
            <w:r><w:t>{{if show_electronics}}</w:t></w:r>
          </w:p>
          <w:p>
            <w:r><w:t>Electronics Section: Laptops, Phones, Tablets</w:t></w:r>
          </w:p>
          <w:p>
            <w:r><w:t>{{endif}}</w:t></w:r>
          </w:p>
          <w:p>
            <w:r><w:t>{{if show_clothing}}</w:t></w:r>
          </w:p>
          <w:p>
            <w:r><w:t>Clothing Section: Shirts, Pants, Jackets</w:t></w:r>
          </w:p>
          <w:p>
            <w:r><w:t>{{endif}}</w:t></w:r>
          </w:p>
          <w:p>
            <w:r><w:t>{{if show_furniture}}</w:t></w:r>
          </w:p>
          <w:p>
            <w:r><w:t>Furniture Section: Tables, Chairs, Sofas</w:t></w:r>
          </w:p>
          <w:p>
            <w:r><w:t>{{endif}}</w:t></w:r>
          </w:p>
          <w:p>
            <w:r><w:t>End of Catalog</w:t></w:r>
          </w:p>
        </w:body>
      </w:document>
      """,
      "word/_rels/document.xml.rels" => document_rels_xml()
    }

    create_docx(file_map, "test/fixtures/conditional_multiple.docx")
    IO.puts("Created: conditional_multiple.docx")
  end

  defp create_conditional_with_variables do
    file_map = %{
      "[Content_Types].xml" => content_types_xml(),
      "_rels/.rels" => rels_xml(),
      "word/document.xml" => """
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:body>
          <w:p>
            <w:r><w:t>Dear {{customer_name}},</w:t></w:r>
          </w:p>
          <w:p>
            <w:r><w:t>{{if has_discount}}</w:t></w:r>
          </w:p>
          <w:p>
            <w:r><w:t>Great news! You have a {{discount_percent}}% discount available.</w:t></w:r>
          </w:p>
          <w:p>
            <w:r><w:t>Use code: {{discount_code}}</w:t></w:r>
          </w:p>
          <w:p>
            <w:r><w:t>{{endif}}</w:t></w:r>
          </w:p>
          <w:p>
            <w:r><w:t>Your order total is: {{total_amount}}</w:t></w:r>
          </w:p>
          <w:p>
            <w:r><w:t>Thank you for shopping with us!</w:t></w:r>
          </w:p>
        </w:body>
      </w:document>
      """,
      "word/_rels/document.xml.rels" => document_rels_xml()
    }

    create_docx(file_map, "test/fixtures/conditional_with_variables.docx")
    IO.puts("Created: conditional_with_variables.docx")
  end

  defp create_docx(file_map, output_path) do
    # Create a temporary directory
    tmp_dir = System.tmp_dir!() <> "/docx_#{:rand.uniform(1_000_000)}"
    File.mkdir_p!(tmp_dir)

    # Get absolute output path
    {:ok, cwd} = File.cwd()
    abs_output_path = Path.expand(output_path, cwd)

    try do
      # Write all files to temp directory
      Enum.each(file_map, fn {path, content} ->
        full_path = Path.join(tmp_dir, path)
        File.mkdir_p!(Path.dirname(full_path))
        File.write!(full_path, content)
      end)

      # Ensure output directory exists
      File.mkdir_p!(Path.dirname(abs_output_path))

      # Zip the directory into a .docx file
      files_list = Enum.map(file_map, fn {path, _} -> to_charlist(path) end)

      File.cd!(tmp_dir)

      result = :zip.create(
        to_charlist(abs_output_path),
        files_list,
        []
      )

      File.cd!(cwd)

      case result do
        {:ok, _} -> :ok
        {:error, reason} ->
          IO.puts("Error creating zip: #{inspect(reason)}")
          raise "Failed to create zip: #{inspect(reason)}"
      end
    after
      File.rm_rf!(tmp_dir)
    end
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
end

ConditionalFixtureCreator.create_all()
