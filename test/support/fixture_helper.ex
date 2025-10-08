defmodule Ootempl.FixtureHelper do
  @moduledoc """
  Helper functions for creating test fixtures.
  """

  @doc """
  Creates a minimal valid .docx file for testing.

  Returns the path to the created fixture file.
  """
  @spec create_minimal_docx(Path.t()) :: Path.t()
  def create_minimal_docx(output_path) do
    file_map = %{
      "[Content_Types].xml" => content_types_xml(),
      "_rels/.rels" => rels_xml(),
      "word/document.xml" => document_xml(),
      "word/_rels/document.xml.rels" => document_rels_xml()
    }

    case Ootempl.Archive.create(file_map, output_path) do
      :ok -> output_path
      {:error, reason} -> raise "Failed to create fixture: #{inspect(reason)}"
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

  defp document_xml do
    """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
      <w:body>
        <w:p>
          <w:r>
            <w:t>Hello, World!</w:t>
          </w:r>
        </w:p>
      </w:body>
    </w:document>
    """
  end

  defp document_rels_xml do
    """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    </Relationships>
    """
  end

  @doc """
  Creates a .docx file with a simple conditional section for testing.

  Returns the path to the created fixture file.
  """
  @spec create_conditional_simple_docx(Path.t()) :: Path.t()
  def create_conditional_simple_docx(output_path) do
    file_map = %{
      "[Content_Types].xml" => content_types_xml(),
      "_rels/.rels" => rels_xml(),
      "word/document.xml" => conditional_simple_document_xml(),
      "word/_rels/document.xml.rels" => document_rels_xml()
    }

    case Ootempl.Archive.create(file_map, output_path) do
      :ok -> output_path
      {:error, reason} -> raise "Failed to create fixture: #{inspect(reason)}"
    end
  end

  @doc """
  Creates a .docx file with multi-paragraph conditional sections for testing.

  Returns the path to the created fixture file.
  """
  @spec create_conditional_multi_paragraph_docx(Path.t()) :: Path.t()
  def create_conditional_multi_paragraph_docx(output_path) do
    file_map = %{
      "[Content_Types].xml" => content_types_xml(),
      "_rels/.rels" => rels_xml(),
      "word/document.xml" => conditional_multi_paragraph_document_xml(),
      "word/_rels/document.xml.rels" => document_rels_xml()
    }

    case Ootempl.Archive.create(file_map, output_path) do
      :ok -> output_path
      {:error, reason} -> raise "Failed to create fixture: #{inspect(reason)}"
    end
  end

  @doc """
  Creates a .docx file with multiple conditionals for testing.

  Returns the path to the created fixture file.
  """
  @spec create_conditional_multiple_docx(Path.t()) :: Path.t()
  def create_conditional_multiple_docx(output_path) do
    file_map = %{
      "[Content_Types].xml" => content_types_xml(),
      "_rels/.rels" => rels_xml(),
      "word/document.xml" => conditional_multiple_document_xml(),
      "word/_rels/document.xml.rels" => document_rels_xml()
    }

    case Ootempl.Archive.create(file_map, output_path) do
      :ok -> output_path
      {:error, reason} -> raise "Failed to create fixture: #{inspect(reason)}"
    end
  end

  @doc """
  Creates a .docx file with a conditional section containing a table for testing.

  Returns the path to the created fixture file.
  """
  @spec create_conditional_with_table_docx(Path.t()) :: Path.t()
  def create_conditional_with_table_docx(output_path) do
    file_map = %{
      "[Content_Types].xml" => content_types_xml(),
      "_rels/.rels" => rels_xml(),
      "word/document.xml" => conditional_with_table_document_xml(),
      "word/_rels/document.xml.rels" => document_rels_xml()
    }

    case Ootempl.Archive.create(file_map, output_path) do
      :ok -> output_path
      {:error, reason} -> raise "Failed to create fixture: #{inspect(reason)}"
    end
  end

  defp conditional_simple_document_xml do
    """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
      <w:body>
        <w:p>
          <w:r><w:t>Before conditional</w:t></w:r>
        </w:p>
        <w:p>
          <w:r><w:t>@if:show_section@</w:t></w:r>
        </w:p>
        <w:p>
          <w:r><w:t>Conditional content that should appear or disappear</w:t></w:r>
        </w:p>
        <w:p>
          <w:r><w:t>@endif@</w:t></w:r>
        </w:p>
        <w:p>
          <w:r><w:t>After conditional</w:t></w:r>
        </w:p>
      </w:body>
    </w:document>
    """
  end

  defp conditional_multi_paragraph_document_xml do
    """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
      <w:body>
        <w:p>
          <w:r><w:t>Document start</w:t></w:r>
        </w:p>
        <w:p>
          <w:r><w:t>@if:show_disclaimer@</w:t></w:r>
        </w:p>
        <w:p>
          <w:r><w:t>DISCLAIMER PARAGRAPH 1</w:t></w:r>
        </w:p>
        <w:p>
          <w:r><w:t>DISCLAIMER PARAGRAPH 2</w:t></w:r>
        </w:p>
        <w:p>
          <w:r><w:t>DISCLAIMER PARAGRAPH 3</w:t></w:r>
        </w:p>
        <w:p>
          <w:r><w:t>@endif@</w:t></w:r>
        </w:p>
        <w:p>
          <w:r><w:t>Document end</w:t></w:r>
        </w:p>
      </w:body>
    </w:document>
    """
  end

  defp conditional_multiple_document_xml do
    """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
      <w:body>
        <w:p>
          <w:r><w:t>Start</w:t></w:r>
        </w:p>
        <w:p>
          <w:r><w:t>@if:first@</w:t></w:r>
        </w:p>
        <w:p>
          <w:r><w:t>First conditional content</w:t></w:r>
        </w:p>
        <w:p>
          <w:r><w:t>@endif@</w:t></w:r>
        </w:p>
        <w:p>
          <w:r><w:t>Middle</w:t></w:r>
        </w:p>
        <w:p>
          <w:r><w:t>@if:second@</w:t></w:r>
        </w:p>
        <w:p>
          <w:r><w:t>Second conditional content</w:t></w:r>
        </w:p>
        <w:p>
          <w:r><w:t>@endif@</w:t></w:r>
        </w:p>
        <w:p>
          <w:r><w:t>End</w:t></w:r>
        </w:p>
      </w:body>
    </w:document>
    """
  end

  defp conditional_with_table_document_xml do
    """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
      <w:body>
        <w:p>
          <w:r><w:t>Before table</w:t></w:r>
        </w:p>
        <w:p>
          <w:r><w:t>@if:show_pricing@</w:t></w:r>
        </w:p>
        <w:tbl>
          <w:tr>
            <w:tc><w:p><w:r><w:t>Item</w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:r><w:t>Price</w:t></w:r></w:p></w:tc>
          </w:tr>
          <w:tr>
            <w:tc><w:p><w:r><w:t>Product A</w:t></w:r></w:p></w:tc>
            <w:tc><w:p><w:r><w:t>$100</w:t></w:r></w:p></w:tc>
          </w:tr>
        </w:tbl>
        <w:p>
          <w:r><w:t>@endif@</w:t></w:r>
        </w:p>
        <w:p>
          <w:r><w:t>After table</w:t></w:r>
        </w:p>
      </w:body>
    </w:document>
    """
  end

  @doc """
  Creates a .docx file with if/else conditional sections for testing.

  Returns the path to the created fixture file.
  """
  @spec create_conditional_if_else_docx(Path.t()) :: Path.t()
  def create_conditional_if_else_docx(output_path) do
    file_map = %{
      "[Content_Types].xml" => content_types_xml(),
      "_rels/.rels" => rels_xml(),
      "word/document.xml" => conditional_if_else_document_xml(),
      "word/_rels/document.xml.rels" => document_rels_xml()
    }

    case Ootempl.Archive.create(file_map, output_path) do
      :ok -> output_path
      {:error, reason} -> raise "Failed to create fixture: #{inspect(reason)}"
    end
  end

  defp conditional_if_else_document_xml do
    """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
      <w:body>
        <w:p>
          <w:r><w:t>Dear Customer,</w:t></w:r>
        </w:p>
        <w:p>
          <w:r><w:t>@if:is_premium@</w:t></w:r>
        </w:p>
        <w:p>
          <w:r><w:t>Thank you for being a premium member! You get 20% off.</w:t></w:r>
        </w:p>
        <w:p>
          <w:r><w:t>@else@</w:t></w:r>
        </w:p>
        <w:p>
          <w:r><w:t>Become a premium member today for 20% off all purchases.</w:t></w:r>
        </w:p>
        <w:p>
          <w:r><w:t>@endif@</w:t></w:r>
        </w:p>
        <w:p>
          <w:r><w:t>Thank you!</w:t></w:r>
        </w:p>
      </w:body>
    </w:document>
    """
  end
end
