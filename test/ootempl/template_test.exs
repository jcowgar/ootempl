defmodule Ootempl.TemplateTest do
  use ExUnit.Case, async: true

  import Ootempl.Xml

  alias Ootempl.Template
  alias Ootempl.Xml

  require Record

  describe "new/1" do
    test "creates template with required fields" do
      # Arrange
      document = xmlElement(name: :"w:document", content: [])
      static_files = %{"word/styles.xml" => "<styles/>"}

      # Act
      template = Template.new(document: document, static_files: static_files)

      # Assert
      assert %Template{} = template
      assert template.document == document
      assert template.static_files == static_files
      assert template.headers == nil
      assert template.footers == nil
    end

    test "creates template with optional fields" do
      # Arrange
      document = xmlElement(name: :"w:document", content: [])
      headers = %{"header1.xml" => xmlElement(name: :"w:hdr", content: [])}
      footers = %{"footer1.xml" => xmlElement(name: :"w:ftr", content: [])}
      footnotes = xmlElement(name: :"w:footnotes", content: [])
      endnotes = xmlElement(name: :"w:endnotes", content: [])
      static_files = %{}

      # Act
      template =
        Template.new(
          document: document,
          headers: headers,
          footers: footers,
          footnotes: footnotes,
          endnotes: endnotes,
          static_files: static_files,
          source_path: "test.docx"
        )

      # Assert
      assert %Template{} = template
      assert template.headers == headers
      assert template.footers == footers
      assert template.footnotes == footnotes
      assert template.endnotes == endnotes
      assert template.source_path == "test.docx"
    end

    test "raises when required fields missing" do
      # Act & Assert
      assert_raise ArgumentError, fn ->
        Template.new(document: xmlElement(name: :"w:document", content: []))
      end

      assert_raise ArgumentError, fn ->
        Template.new(static_files: %{})
      end
    end
  end

  describe "clone_xml/1" do
    test "clones simple XML element" do
      # Arrange
      element =
        xmlElement(
          name: :"w:p",
          attributes: [],
          content: [],
          expanded_name: :"w:p",
          namespace: {:xmlNamespace, [], []},
          parents: [],
          pos: 1,
          language: []
        )

      # Act
      cloned = Template.clone_xml(element)

      # Assert
      assert Record.is_record(cloned, :xmlElement)
      assert xmlElement(cloned, :name) == :"w:p"
      # Verify clone has the same structure
      assert xmlElement(cloned, :attributes) == xmlElement(element, :attributes)
      assert xmlElement(cloned, :content) == xmlElement(element, :content)
    end

    test "clones element with text content" do
      # Arrange
      text_node = xmlText(value: ~c"Hello World", parents: [], pos: 1, language: [], type: :text)

      element =
        xmlElement(
          name: :"w:t",
          content: [text_node],
          attributes: [],
          expanded_name: :"w:t",
          namespace: {:xmlNamespace, [], []},
          parents: [],
          pos: 1,
          language: []
        )

      # Act
      cloned = Template.clone_xml(element)

      # Assert
      assert Record.is_record(cloned, :xmlElement)
      content = xmlElement(cloned, :content)
      assert length(content) == 1
      [cloned_text] = content
      assert Record.is_record(cloned_text, :xmlText)
      assert xmlText(cloned_text, :value) == ~c"Hello World"
    end

    test "clones nested XML elements" do
      # Arrange
      inner_text = xmlText(value: ~c"Text", parents: [], pos: 1, language: [], type: :text)

      inner_element =
        xmlElement(
          name: :"w:t",
          content: [inner_text],
          attributes: [],
          expanded_name: :"w:t",
          namespace: {:xmlNamespace, [], []},
          parents: [],
          pos: 1,
          language: []
        )

      outer_element =
        xmlElement(
          name: :"w:r",
          content: [inner_element],
          attributes: [],
          expanded_name: :"w:r",
          namespace: {:xmlNamespace, [], []},
          parents: [],
          pos: 1,
          language: []
        )

      # Act
      cloned = Template.clone_xml(outer_element)

      # Assert
      assert Record.is_record(cloned, :xmlElement)
      assert xmlElement(cloned, :name) == :"w:r"

      content = xmlElement(cloned, :content)
      assert length(content) == 1
      [cloned_inner] = content
      assert Record.is_record(cloned_inner, :xmlElement)
      assert xmlElement(cloned_inner, :name) == :"w:t"
    end

    test "clones element with attributes" do
      # Arrange
      attributes = [
        xmlAttribute(name: :val, value: ~c"test"),
        xmlAttribute(name: :id, value: ~c"123")
      ]

      element =
        xmlElement(
          name: :"w:p",
          attributes: attributes,
          content: [],
          expanded_name: :"w:p",
          namespace: {:xmlNamespace, [], []},
          parents: [],
          pos: 1,
          language: []
        )

      # Act
      cloned = Template.clone_xml(element)

      # Assert
      cloned_attrs = xmlElement(cloned, :attributes)
      assert length(cloned_attrs) == 2
    end

    test "preserves element metadata during cloning" do
      # Arrange
      element =
        xmlElement(
          name: :"w:p",
          attributes: [],
          content: [],
          expanded_name: {:"http://example.com", :"w:p"},
          namespace: {:xmlNamespace, [], []},
          parents: [{:"w:body", 1}],
          pos: 5,
          language: ~c"en"
        )

      # Act
      cloned = Template.clone_xml(element)

      # Assert
      assert xmlElement(cloned, :expanded_name) == {:"http://example.com", :"w:p"}
      assert xmlElement(cloned, :pos) == 5
      assert xmlElement(cloned, :language) == ~c"en"
    end

    test "handles non-element input by returning as-is" do
      # Arrange
      text_node = xmlText(value: ~c"test", parents: [], pos: 1, language: [], type: :text)

      # Act
      result = Template.clone_xml(text_node)

      # Assert
      assert result == text_node
    end

    test "cloning creates independent copies" do
      # Arrange
      text1 = xmlText(value: ~c"original", parents: [], pos: 1, language: [], type: :text)

      element =
        xmlElement(
          name: :"w:t",
          content: [text1],
          attributes: [],
          expanded_name: :"w:t",
          namespace: {:xmlNamespace, [], []},
          parents: [],
          pos: 1,
          language: []
        )

      # Act
      cloned = Template.clone_xml(element)

      # Modify the original
      modified_text = xmlText(text1, value: ~c"modified")

      modified_element =
        xmlElement(element,
          content: [modified_text]
        )

      # Assert - cloned should still have original value
      [cloned_content] = xmlElement(cloned, :content)
      assert xmlText(cloned_content, :value) == ~c"original"

      [modified_content] = xmlElement(modified_element, :content)
      assert xmlText(modified_content, :value) == ~c"modified"
    end
  end

  describe "clone_xml_map/1" do
    test "clones empty map" do
      # Arrange
      xml_map = %{}

      # Act
      cloned = Template.clone_xml_map(xml_map)

      # Assert
      assert cloned == %{}
    end

    test "clones map with single element" do
      # Arrange
      element =
        xmlElement(
          name: :"w:hdr",
          content: [],
          attributes: [],
          expanded_name: :"w:hdr",
          namespace: {:xmlNamespace, [], []},
          parents: [],
          pos: 1,
          language: []
        )

      xml_map = %{"header1.xml" => element}

      # Act
      cloned = Template.clone_xml_map(xml_map)

      # Assert
      assert Map.has_key?(cloned, "header1.xml")
      cloned_element = cloned["header1.xml"]
      assert Record.is_record(cloned_element, :xmlElement)
      assert xmlElement(cloned_element, :name) == :"w:hdr"
      # Verify the structure matches
      assert xmlElement(cloned_element, :content) == []
    end

    test "clones map with multiple elements" do
      # Arrange
      header1 =
        xmlElement(
          name: :"w:hdr",
          content: [],
          attributes: [],
          expanded_name: :"w:hdr",
          namespace: {:xmlNamespace, [], []},
          parents: [],
          pos: 1,
          language: []
        )

      header2 =
        xmlElement(
          name: :"w:hdr",
          content: [],
          attributes: [],
          expanded_name: :"w:hdr",
          namespace: {:xmlNamespace, [], []},
          parents: [],
          pos: 2,
          language: []
        )

      footer1 =
        xmlElement(
          name: :"w:ftr",
          content: [],
          attributes: [],
          expanded_name: :"w:ftr",
          namespace: {:xmlNamespace, [], []},
          parents: [],
          pos: 3,
          language: []
        )

      xml_map = %{
        "header1.xml" => header1,
        "header2.xml" => header2,
        "footer1.xml" => footer1
      }

      # Act
      cloned = Template.clone_xml_map(xml_map)

      # Assert
      assert map_size(cloned) == 3
      assert Map.has_key?(cloned, "header1.xml")
      assert Map.has_key?(cloned, "header2.xml")
      assert Map.has_key?(cloned, "footer1.xml")

      # Verify each element has the correct structure
      assert xmlElement(cloned["header1.xml"], :name) == :"w:hdr"
      assert xmlElement(cloned["header2.xml"], :name) == :"w:hdr"
      assert xmlElement(cloned["footer1.xml"], :name) == :"w:ftr"
    end

    test "preserves map keys during cloning" do
      # Arrange
      element =
        xmlElement(
          name: :"w:hdr",
          content: [],
          attributes: [],
          expanded_name: :"w:hdr",
          namespace: {:xmlNamespace, [], []},
          parents: [],
          pos: 1,
          language: []
        )

      xml_map = %{"word/header1.xml" => element}

      # Act
      cloned = Template.clone_xml_map(xml_map)

      # Assert
      assert Map.keys(cloned) == ["word/header1.xml"]
    end

    test "clones complex nested XML in map values" do
      # Arrange
      text = xmlText(value: ~c"Header Text", parents: [], pos: 1, language: [], type: :text)

      text_element =
        xmlElement(
          name: :"w:t",
          content: [text],
          attributes: [],
          expanded_name: :"w:t",
          namespace: {:xmlNamespace, [], []},
          parents: [],
          pos: 1,
          language: []
        )

      run_element =
        xmlElement(
          name: :"w:r",
          content: [text_element],
          attributes: [],
          expanded_name: :"w:r",
          namespace: {:xmlNamespace, [], []},
          parents: [],
          pos: 1,
          language: []
        )

      para_element =
        xmlElement(
          name: :"w:p",
          content: [run_element],
          attributes: [],
          expanded_name: :"w:p",
          namespace: {:xmlNamespace, [], []},
          parents: [],
          pos: 1,
          language: []
        )

      header_element =
        xmlElement(
          name: :"w:hdr",
          content: [para_element],
          attributes: [],
          expanded_name: :"w:hdr",
          namespace: {:xmlNamespace, [], []},
          parents: [],
          pos: 1,
          language: []
        )

      xml_map = %{"header1.xml" => header_element}

      # Act
      cloned = Template.clone_xml_map(xml_map)

      # Assert
      cloned_header = cloned["header1.xml"]
      assert Record.is_record(cloned_header, :xmlElement)

      [cloned_para] = xmlElement(cloned_header, :content)
      assert xmlElement(cloned_para, :name) == :"w:p"

      [cloned_run] = xmlElement(cloned_para, :content)
      assert xmlElement(cloned_run, :name) == :"w:r"

      [cloned_text_elem] = xmlElement(cloned_run, :content)
      [cloned_text_node] = xmlElement(cloned_text_elem, :content)
      assert xmlText(cloned_text_node, :value) == ~c"Header Text"
    end

    test "handles cloning XML map with different value types" do
      # Arrange
      text_node = xmlText(value: ~c"text", parents: [], pos: 1, language: [], type: :text)

      element1 =
        xmlElement(
          name: :"w:hdr",
          content: [text_node],
          attributes: [],
          expanded_name: :"w:hdr",
          namespace: {:xmlNamespace, [], []},
          parents: [],
          pos: 1,
          language: []
        )

      element2 =
        xmlElement(
          name: :"w:ftr",
          content: [],
          attributes: [],
          expanded_name: :"w:ftr",
          namespace: {:xmlNamespace, [], []},
          parents: [],
          pos: 1,
          language: []
        )

      xml_map = %{
        "header1.xml" => element1,
        "footer1.xml" => element2
      }

      # Act
      cloned = Template.clone_xml_map(xml_map)

      # Assert
      assert map_size(cloned) == 2
      assert Map.has_key?(cloned, "header1.xml")
      assert Map.has_key?(cloned, "footer1.xml")

      # Verify structure is preserved
      cloned_header = cloned["header1.xml"]
      assert xmlElement(cloned_header, :name) == :"w:hdr"
      [cloned_text] = xmlElement(cloned_header, :content)
      assert xmlText(cloned_text, :value) == ~c"text"

      cloned_footer = cloned["footer1.xml"]
      assert xmlElement(cloned_footer, :name) == :"w:ftr"
      assert xmlElement(cloned_footer, :content) == []
    end
  end

  describe "clone_xml/1 edge cases" do
    test "handles cloning elements with multiple attributes" do
      # Arrange
      attrs = [
        xmlAttribute(name: :id, value: ~c"123"),
        xmlAttribute(name: :style, value: ~c"bold"),
        xmlAttribute(name: :class, value: ~c"heading")
      ]

      element =
        xmlElement(
          name: :p,
          attributes: attrs,
          content: [],
          expanded_name: :p,
          namespace: {:xmlNamespace, [], []},
          parents: [],
          pos: 1,
          language: []
        )

      # Act
      cloned = Template.clone_xml(element)

      # Assert
      cloned_attrs = xmlElement(cloned, :attributes)
      assert length(cloned_attrs) == 3
    end

    test "handles cloning elements with mixed content" do
      # Arrange
      text1 = xmlText(value: ~c"Start ", parents: [], pos: 1, language: [], type: :text)

      child_elem =
        xmlElement(
          name: :b,
          content: [xmlText(value: ~c"bold", parents: [], pos: 1, language: [], type: :text)],
          attributes: [],
          expanded_name: :b,
          namespace: {:xmlNamespace, [], []},
          parents: [],
          pos: 1,
          language: []
        )

      text2 = xmlText(value: ~c" end", parents: [], pos: 2, language: [], type: :text)

      element =
        xmlElement(
          name: :p,
          content: [text1, child_elem, text2],
          attributes: [],
          expanded_name: :p,
          namespace: {:xmlNamespace, [], []},
          parents: [],
          pos: 1,
          language: []
        )

      # Act
      cloned = Template.clone_xml(element)

      # Assert
      cloned_content = xmlElement(cloned, :content)
      assert length(cloned_content) == 3
    end

    test "handles cloning with namespace information" do
      # Arrange
      namespace = {:xmlNamespace, [{"w", "http://schemas.openxmlformats.org/wordprocessingml/2006/main"}], []}

      element =
        xmlElement(
          name: :"w:p",
          attributes: [],
          content: [],
          expanded_name: {:"http://schemas.openxmlformats.org/wordprocessingml/2006/main", :p},
          namespace: namespace,
          parents: [],
          pos: 1,
          language: []
        )

      # Act
      cloned = Template.clone_xml(element)

      # Assert
      assert xmlElement(cloned, :name) == :"w:p"
      cloned_namespace = xmlElement(cloned, :namespace)
      assert is_tuple(cloned_namespace)
    end
  end
end
