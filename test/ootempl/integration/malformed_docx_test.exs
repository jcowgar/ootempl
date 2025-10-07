defmodule Ootempl.Integration.MalformedDocxTest do
  use ExUnit.Case, async: true

  @fixtures_dir "test/fixtures"
  @temp_malformed_dir Path.join(@fixtures_dir, "malformed")

  setup do
    # Create temp directory for malformed test files
    File.mkdir_p!(@temp_malformed_dir)

    on_exit(fn ->
      File.rm_rf(@temp_malformed_dir)
    end)

    :ok
  end

  describe "malformed XML error handling" do
    test "detects unclosed XML tags in document.xml" do
      # Create a .docx with malformed XML
      malformed_path = Path.join(@temp_malformed_dir, "unclosed_tags.docx")
      output_path = Path.join(@temp_malformed_dir, "unclosed_tags_output.docx")

      malformed_xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:body>
          <w:p>
            <w:r>
              <w:t>This tag is not closed
          </w:p>
        </w:body>
      </w:document>
      """

      create_docx_with_malformed_xml(malformed_path, malformed_xml)

      # Should return MalformedXMLError when trying to render
      result = Ootempl.render(malformed_path, %{}, output_path)

      assert {:error, %Ootempl.MalformedXMLError{xml_file: "word/document.xml"}} = result
    end

    test "detects invalid XML syntax in document.xml" do
      malformed_path = Path.join(@temp_malformed_dir, "invalid_syntax.docx")
      output_path = Path.join(@temp_malformed_dir, "invalid_syntax_output.docx")

      # XML with invalid characters and broken structure
      malformed_xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:body>
          <w:p><<INVALID>></w:p>
        </w:body>
      </w:document>
      """

      create_docx_with_malformed_xml(malformed_path, malformed_xml)

      result = Ootempl.render(malformed_path, %{}, output_path)

      assert {:error, %Ootempl.MalformedXMLError{}} = result
    end

    test "detects mismatched XML tags" do
      malformed_path = Path.join(@temp_malformed_dir, "mismatched_tags.docx")
      output_path = Path.join(@temp_malformed_dir, "mismatched_tags_output.docx")

      malformed_xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:body>
          <w:p>
            <w:r>
              <w:t>Text</w:t>
            </w:r>
          </w:wrong>
        </w:body>
      </w:document>
      """

      create_docx_with_malformed_xml(malformed_path, malformed_xml)

      result = Ootempl.render(malformed_path, %{}, output_path)

      assert {:error, %Ootempl.MalformedXMLError{}} = result
    end

    test "handles rendering attempt on malformed XML" do
      malformed_path = Path.join(@temp_malformed_dir, "render_malformed.docx")
      output_path = Path.join(@temp_malformed_dir, "output.docx")

      malformed_xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:body>
          <unclosed>
        </w:body>
      </w:document>
      """

      create_docx_with_malformed_xml(malformed_path, malformed_xml)

      result = Ootempl.render(malformed_path, %{}, output_path)

      assert {:error, %Ootempl.MalformedXMLError{}} = result
    end

    test "detects empty document.xml" do
      malformed_path = Path.join(@temp_malformed_dir, "empty_document.docx")
      output_path = Path.join(@temp_malformed_dir, "empty_document_output.docx")

      # Completely empty XML
      create_docx_with_malformed_xml(malformed_path, "")

      result = Ootempl.render(malformed_path, %{}, output_path)

      assert {:error, %Ootempl.MalformedXMLError{}} = result
    end

    test "detects XML with only declaration but no content" do
      malformed_path = Path.join(@temp_malformed_dir, "declaration_only.docx")
      output_path = Path.join(@temp_malformed_dir, "declaration_only_output.docx")

      create_docx_with_malformed_xml(malformed_path, ~s(<?xml version="1.0"?>))

      result = Ootempl.render(malformed_path, %{}, output_path)

      assert {:error, %Ootempl.MalformedXMLError{}} = result
    end
  end

  describe "missing required files" do
    test "detects missing document.xml" do
      malformed_path = Path.join(@temp_malformed_dir, "missing_document.docx")
      output_path = Path.join(@temp_malformed_dir, "missing_document_output.docx")

      # Create .docx without word/document.xml
      files = %{
        "[Content_Types].xml" => minimal_content_types_xml(),
        "_rels/.rels" => minimal_rels_xml()
      }

      create_zip(malformed_path, files)

      result = Ootempl.render(malformed_path, %{}, output_path)

      assert {:error, %Ootempl.MissingFileError{missing_file: "word/document.xml"}} = result
    end

    test "detects missing [Content_Types].xml" do
      malformed_path = Path.join(@temp_malformed_dir, "missing_content_types.docx")
      output_path = Path.join(@temp_malformed_dir, "missing_content_types_output.docx")

      files = %{
        "word/document.xml" => minimal_document_xml(),
        "_rels/.rels" => minimal_rels_xml()
      }

      create_zip(malformed_path, files)

      result = Ootempl.render(malformed_path, %{}, output_path)

      assert {:error, %Ootempl.MissingFileError{missing_file: "[Content_Types].xml"}} = result
    end

    test "detects missing _rels/.rels" do
      malformed_path = Path.join(@temp_malformed_dir, "missing_rels.docx")
      output_path = Path.join(@temp_malformed_dir, "missing_rels_output.docx")

      files = %{
        "word/document.xml" => minimal_document_xml(),
        "[Content_Types].xml" => minimal_content_types_xml()
      }

      create_zip(malformed_path, files)

      result = Ootempl.render(malformed_path, %{}, output_path)

      assert {:error, %Ootempl.MissingFileError{missing_file: "_rels/.rels"}} = result
    end
  end

  # Helper functions

  defp create_docx_with_malformed_xml(path, malformed_document_xml) do
    files = %{
      "word/document.xml" => malformed_document_xml,
      "[Content_Types].xml" => minimal_content_types_xml(),
      "_rels/.rels" => minimal_rels_xml()
    }

    create_zip(path, files)
  end

  defp create_zip(path, files) do
    file_list =
      Enum.map(files, fn {internal_path, content} ->
        {String.to_charlist(internal_path), content}
      end)

    {:ok, _} = :zip.create(String.to_charlist(path), file_list)
    :ok
  end

  defp minimal_document_xml do
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
      <w:body>
        <w:p>
          <w:r>
            <w:t>Test</w:t>
          </w:r>
        </w:p>
      </w:body>
    </w:document>
    """
  end

  defp minimal_content_types_xml do
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
      <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
      <Default Extension="xml" ContentType="application/xml"/>
      <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
    </Types>
    """
  end

  defp minimal_rels_xml do
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
    </Relationships>
    """
  end
end
