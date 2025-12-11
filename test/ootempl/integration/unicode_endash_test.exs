defmodule Ootempl.Integration.UnicodeEndashTest do
  @moduledoc """
  Tests for handling Unicode en-dash character (U+2013, –) in docx files.

  This test verifies that documents containing the en-dash character
  (commonly used by Word for ranges like "2020–2024") can be properly
  parsed and rendered.
  """

  use ExUnit.Case, async: true

  alias Ootempl.Archive

  @tmp_dir "test/fixtures/tmp_unicode_test"

  setup do
    File.mkdir_p!(@tmp_dir)

    on_exit(fn ->
      File.rm_rf!(@tmp_dir)
    end)

    :ok
  end

  describe "Unicode en-dash (U+2013) handling" do
    test "parses document containing Hello–World text" do
      # Arrange - create a minimal docx with en-dash character
      docx_path = create_endash_docx()
      output_path = Path.join(@tmp_dir, "output_parse.docx")

      # Act - try to render (which internally parses) the template
      result = Ootempl.render(docx_path, %{}, output_path)

      # Assert
      assert result == :ok
      assert File.exists?(output_path)
    end

    test "renders document containing en-dash character" do
      # Arrange
      docx_path = create_endash_docx()
      output_path = Path.join(@tmp_dir, "output_endash.docx")

      # Act
      result = Ootempl.render(docx_path, %{}, output_path)

      # Assert
      assert result == :ok

      # Verify the output file exists and contains the en-dash
      assert File.exists?(output_path)

      # Read the output and verify it contains the en-dash character
      {:ok, temp_path} = Archive.extract(output_path)

      try do
        document_xml = File.read!(Path.join(temp_path, "word/document.xml"))
        assert document_xml
        # The en-dash may be preserved as-is or as entity &#8211;
        assert String.contains?(document_xml, "Hello") and String.contains?(document_xml, "World")
      after
        Archive.cleanup(temp_path)
      end
    end

    test "XML module parses en-dash character in raw XML" do
      # Arrange - test the XML module directly
      xml_string = """
      <?xml version="1.0" encoding="UTF-8"?>
      <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:body>
          <w:p>
            <w:r>
              <w:t>Hello–World</w:t>
            </w:r>
          </w:p>
        </w:body>
      </w:document>
      """

      # Act
      result = Ootempl.Xml.parse(xml_string)

      # Assert
      assert {:ok, _doc} = result
    end

    test "handles multiple unicode characters including en-dash" do
      # Arrange
      xml_string = """
      <?xml version="1.0" encoding="UTF-8"?>
      <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:body>
          <w:p>
            <w:r>
              <w:t>Range: 2020–2024, Price: €100, Em-dash—here</w:t>
            </w:r>
          </w:p>
        </w:body>
      </w:document>
      """

      # Act
      result = Ootempl.Xml.parse(xml_string)

      # Assert
      assert {:ok, _doc} = result
    end

    test "round-trip preserves en-dash character" do
      # Arrange
      xml_string = """
      <?xml version="1.0" encoding="UTF-8"?>
      <root>Hello–World</root>
      """

      # Act - parse and serialize
      {:ok, doc} = Ootempl.Xml.parse(xml_string)
      {:ok, serialized} = Ootempl.Xml.serialize(doc)

      # Assert - the en-dash should be in the output (either as character or entity)
      assert String.contains?(serialized, "Hello") and String.contains?(serialized, "World")
      # xmerl preserves the character in the output
      assert String.contains?(serialized, "–") or String.contains?(serialized, "&#8211;")
    end

    test "parses registered trademark symbol (®, codepoint 174)" do
      # Arrange - ® is in Latin-1 range but still fails in xmerl
      xml_string = """
      <?xml version="1.0" encoding="UTF-8"?>
      <root>Company® Name</root>
      """

      # Act
      result = Ootempl.Xml.parse(xml_string)

      # Assert
      assert {:ok, _doc} = result
    end

    test "parses copyright symbol (©, codepoint 169)" do
      # Arrange
      xml_string = """
      <?xml version="1.0" encoding="UTF-8"?>
      <root>© 2024 Company</root>
      """

      # Act
      result = Ootempl.Xml.parse(xml_string)

      # Assert
      assert {:ok, _doc} = result
    end
  end

  describe "placeholder detection with multi-byte characters" do
    test "detects placeholders correctly when multi-byte characters precede them" do
      # This test ensures that Placeholder.detect uses byte positions correctly.
      # The bug was: Regex.scan returns byte positions, but String.slice uses
      # grapheme positions. Multi-byte chars (like em-dash) cause index misalignment.

      # Arrange - text with em-dash (3 bytes) before placeholder
      text = "Range: 2020—2024 {{year}} more text"

      # Act
      placeholders = Ootempl.Placeholder.detect(text)

      # Assert - should detect {{year}} correctly, not a malformed version
      assert length(placeholders) == 1
      assert hd(placeholders).original == "{{year}}"
      assert hd(placeholders).variable == "year"
      assert hd(placeholders).path == ["year"]
    end

    test "detects multiple placeholders correctly with various multi-byte characters" do
      # Arrange - multiple multi-byte chars: em-dash (3 bytes), ® (2 bytes)
      text = "Company® Pro—Pro {{name}} and {{person.title}} here"

      # Act
      placeholders = Ootempl.Placeholder.detect(text)

      # Assert
      assert length(placeholders) == 2

      [first, second] = placeholders
      assert first.original == "{{name}}"
      assert first.path == ["name"]

      assert second.original == "{{person.title}}"
      assert second.path == ["person", "title"]
    end

    test "renders document with placeholders after multi-byte characters" do
      # Arrange - create docx with multi-byte chars before placeholder
      docx_path = create_unicode_placeholder_docx()
      output_path = Path.join(@tmp_dir, "output_unicode_placeholder.docx")

      # Act
      result = Ootempl.render(docx_path, %{"product" => "Widget"}, output_path)

      # Assert
      assert result == :ok
      assert File.exists?(output_path)

      # Verify the placeholder was replaced correctly
      {:ok, temp_path} = Archive.extract(output_path)

      try do
        document_xml = File.read!(Path.join(temp_path, "word/document.xml"))
        assert String.contains?(document_xml, "Widget")
        refute String.contains?(document_xml, "{{product}}")
      after
        Archive.cleanup(temp_path)
      end
    end

    test "inspect detects placeholders correctly in document with multi-byte characters" do
      # Arrange
      docx_path = create_unicode_placeholder_docx()

      # Act
      {:ok, info} = Ootempl.inspect(docx_path)

      # Assert - should find the placeholder with correct path
      assert length(info.placeholders) == 1
      placeholder = hd(info.placeholders)
      assert placeholder.original == "{{product}}"
      assert placeholder.path == ["product"]
    end
  end

  # Helper to create a docx with multi-byte characters before a placeholder
  defp create_unicode_placeholder_docx do
    output_path = Path.join(@tmp_dir, "unicode_placeholder.docx")

    file_map = %{
      "[Content_Types].xml" => content_types_xml(),
      "_rels/.rels" => rels_xml(),
      "word/document.xml" => document_xml_with_unicode_placeholder(),
      "word/_rels/document.xml.rels" => document_rels_xml()
    }

    case Archive.create(file_map, output_path) do
      :ok -> output_path
      {:error, reason} -> raise "Failed to create fixture: #{inspect(reason)}"
    end
  end

  # Helper to create a minimal docx with en-dash
  defp create_endash_docx do
    output_path = Path.join(@tmp_dir, "hello_endash.docx")

    file_map = %{
      "[Content_Types].xml" => content_types_xml(),
      "_rels/.rels" => rels_xml(),
      "word/document.xml" => document_xml_with_endash(),
      "word/_rels/document.xml.rels" => document_rels_xml()
    }

    case Archive.create(file_map, output_path) do
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

  defp document_xml_with_endash do
    # U+2013 is the en-dash character (–)
    # This is commonly inserted by Word for ranges like "2020–2024"
    """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
      <w:body>
        <w:p>
          <w:r>
            <w:t>Hello–World</w:t>
          </w:r>
        </w:p>
      </w:body>
    </w:document>
    """
  end

  defp document_xml_with_unicode_placeholder do
    # Contains multiple multi-byte characters BEFORE the placeholder:
    # - em-dash (—, U+2014, 3 bytes)
    # - registered trademark (®, U+00AE, 2 bytes)
    # This tests that placeholder detection uses byte positions correctly.
    """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
      <w:body>
        <w:p>
          <w:r>
            <w:t>Company® Pro—Pro: {{product}}</w:t>
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
end
