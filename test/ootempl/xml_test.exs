defmodule Ootempl.XmlTest do
  use ExUnit.Case, async: true

  import Ootempl.Xml

  alias Ootempl.Xml

  require Record

  describe "parse/1" do
    test "parses simple XML document" do
      # Arrange
      xml_string = """
      <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:body>
          <w:p><w:r><w:t>Hello</w:t></w:r></w:p>
        </w:body>
      </w:document>
      """

      # Act
      result = Xml.parse(xml_string)

      # Assert
      assert {:ok, element} = result
      assert Record.is_record(element, :xmlElement)
      assert xmlElement(element, :name) == :"w:document"
    end

    test "parses XML with attributes" do
      # Arrange
      xml_string = """
      <root attr="value" id="123">
        <child/>
      </root>
      """

      # Act
      {:ok, element} = Xml.parse(xml_string)

      # Assert
      attrs = xmlElement(element, :attributes)
      assert length(attrs) == 2
    end

    test "parses empty element" do
      # Arrange
      xml_string = "<root/>"

      # Act
      {:ok, element} = Xml.parse(xml_string)

      # Assert
      assert xmlElement(element, :name) == :root
      assert xmlElement(element, :content) == []
    end

    test "parses XML with text content" do
      # Arrange
      xml_string = "<text>Hello World</text>"

      # Act
      {:ok, element} = Xml.parse(xml_string)

      # Assert
      content = xmlElement(element, :content)
      assert length(content) == 1
      [text_node] = content
      assert Record.is_record(text_node, :xmlText)
    end

    test "returns error for malformed XML - unclosed tag" do
      # Arrange
      xml_string = "<root><child></root>"

      # Act
      result = Xml.parse(xml_string)

      # Assert
      assert {:error, reason} = result
      assert is_tuple(reason)
    end

    test "returns error for malformed XML - invalid character" do
      # Arrange
      xml_string = "<root><INVAL"

      # Act
      result = Xml.parse(xml_string)

      # Assert
      assert {:error, _reason} = result
    end

    test "returns error for empty string" do
      # Arrange
      xml_string = ""

      # Act
      result = Xml.parse(xml_string)

      # Assert
      assert {:error, _reason} = result
    end

    test "parses XML with namespaces" do
      # Arrange
      xml_string = """
      <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
                  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
        <w:body>
          <w:p r:id="1"/>
        </w:body>
      </w:document>
      """

      # Act
      {:ok, element} = Xml.parse(xml_string)

      # Assert
      assert Record.is_record(element, :xmlElement)
      ns = xmlElement(element, :namespace)
      assert is_tuple(ns)
    end

    test "parses deeply nested XML" do
      # Arrange
      xml_string = """
      <level1>
        <level2>
          <level3>
            <level4>
              <level5>Deep</level5>
            </level4>
          </level3>
        </level2>
      </level1>
      """

      # Act
      {:ok, element} = Xml.parse(xml_string)

      # Assert
      assert xmlElement(element, :name) == :level1
      content = xmlElement(element, :content)
      # Filter out text nodes (whitespace)
      elements = Enum.filter(content, &Record.is_record(&1, :xmlElement))
      assert length(elements) == 1
      [level2] = elements
      assert xmlElement(level2, :name) == :level2
    end

    test "handles XML with CDATA sections" do
      # Arrange
      xml_string = "<root><![CDATA[<special>chars</special>]]></root>"

      # Act
      {:ok, element} = Xml.parse(xml_string)

      # Assert
      content = xmlElement(element, :content)
      assert length(content) > 0
    end

    test "handles XML with comments" do
      # Arrange
      xml_string = """
      <root>
        <!-- This is a comment -->
        <child/>
      </root>
      """

      # Act
      {:ok, element} = Xml.parse(xml_string)

      # Assert
      assert Record.is_record(element, :xmlElement)
    end
  end

  describe "serialize/1" do
    test "serializes simple XML element" do
      # Arrange
      element = xmlElement(name: :root, content: [], attributes: [])

      # Act
      {:ok, xml_string} = Xml.serialize(element)

      # Assert
      assert is_binary(xml_string)
      assert xml_string =~ "<root"
    end

    test "serializes XML with text content" do
      # Arrange
      text = xmlText(value: ~c"Hello World")
      element = xmlElement(name: :text, content: [text], attributes: [])

      # Act
      {:ok, xml_string} = Xml.serialize(element)

      # Assert
      assert xml_string =~ "Hello World"
    end

    test "serializes XML with attributes" do
      # Arrange
      attrs = [
        xmlAttribute(name: :id, value: ~c"123"),
        xmlAttribute(name: :type, value: ~c"test")
      ]

      element = xmlElement(name: :root, attributes: attrs, content: [])

      # Act
      {:ok, xml_string} = Xml.serialize(element)

      # Assert
      assert xml_string =~ "id"
      assert xml_string =~ "123"
    end

    test "round-trip parse and serialize preserves structure" do
      # Arrange
      original_xml = "<root><child attr=\"val\">text</child></root>"

      # Act
      {:ok, parsed} = Xml.parse(original_xml)
      {:ok, serialized} = Xml.serialize(parsed)
      {:ok, reparsed} = Xml.parse(serialized)

      # Assert
      assert xmlElement(parsed, :name) == xmlElement(reparsed, :name)
    end
  end

  describe "remove_nodes/2" do
    test "removes single node from element" do
      # Arrange
      text1 = xmlText(value: ~c"Keep")
      text2 = xmlText(value: ~c"Remove")
      text3 = xmlText(value: ~c"Keep")
      element = xmlElement(name: :root, content: [text1, text2, text3], attributes: [])

      nodes_to_remove = [text2]

      # Act
      updated = Xml.remove_nodes(element, nodes_to_remove)

      # Assert
      content = xmlElement(updated, :content)
      assert length(content) == 2
    end

    test "removes multiple nodes from element" do
      # Arrange
      child1 = xmlElement(name: :child1, content: [], attributes: [])
      child2 = xmlElement(name: :child2, content: [], attributes: [])
      child3 = xmlElement(name: :child3, content: [], attributes: [])
      element = xmlElement(name: :root, content: [child1, child2, child3], attributes: [])

      nodes_to_remove = [child1, child3]

      # Act
      updated = Xml.remove_nodes(element, nodes_to_remove)

      # Assert
      content = xmlElement(updated, :content)
      assert length(content) == 1
      [remaining] = content
      assert xmlElement(remaining, :name) == :child2
    end

    test "returns unchanged element when no nodes match" do
      # Arrange
      child = xmlElement(name: :child, content: [], attributes: [])
      element = xmlElement(name: :root, content: [child], attributes: [])
      other_node = xmlElement(name: :other, content: [], attributes: [])

      # Act
      updated = Xml.remove_nodes(element, [other_node])

      # Assert
      content = xmlElement(updated, :content)
      assert length(content) == 1
    end

    test "removes all nodes when all match" do
      # Arrange
      child1 = xmlElement(name: :child1, content: [], attributes: [])
      child2 = xmlElement(name: :child2, content: [], attributes: [])
      element = xmlElement(name: :root, content: [child1, child2], attributes: [])

      # Act
      updated = Xml.remove_nodes(element, [child1, child2])

      # Assert
      content = xmlElement(updated, :content)
      assert content == []
    end

    test "handles empty nodes_to_remove list" do
      # Arrange
      child = xmlElement(name: :child, content: [], attributes: [])
      element = xmlElement(name: :root, content: [child], attributes: [])

      # Act
      updated = Xml.remove_nodes(element, [])

      # Assert
      content = xmlElement(updated, :content)
      assert length(content) == 1
    end

    test "removes nodes recursively from nested structure" do
      # Arrange
      text1 = xmlText(value: ~c"Remove")
      child1 = xmlElement(name: :child, content: [text1], attributes: [])
      element = xmlElement(name: :root, content: [child1], attributes: [])

      # Act
      updated = Xml.remove_nodes(element, [text1])

      # Assert
      [child_updated] = xmlElement(updated, :content)
      child_content = xmlElement(child_updated, :content)
      assert child_content == []
    end
  end

  describe "serialize/1 edge cases" do
    test "handles serialization of complex nested structures" do
      # Arrange
      inner_text = xmlText(value: ~c"Deep text", parents: [], pos: 1, language: [], type: :text)

      inner_elem =
        xmlElement(
          name: :inner,
          content: [inner_text],
          attributes: [],
          expanded_name: :inner,
          namespace: {:xmlNamespace, [], []},
          parents: [],
          pos: 1,
          language: []
        )

      middle_elem =
        xmlElement(
          name: :middle,
          content: [inner_elem],
          attributes: [],
          expanded_name: :middle,
          namespace: {:xmlNamespace, [], []},
          parents: [],
          pos: 1,
          language: []
        )

      outer_elem =
        xmlElement(
          name: :outer,
          content: [middle_elem],
          attributes: [],
          expanded_name: :outer,
          namespace: {:xmlNamespace, [], []},
          parents: [],
          pos: 1,
          language: []
        )

      # Act
      {:ok, xml_string} = Xml.serialize(outer_elem)

      # Assert
      assert is_binary(xml_string)
      assert xml_string =~ "outer"
      assert xml_string =~ "middle"
      assert xml_string =~ "inner"
      assert xml_string =~ "Deep text"
    end

    test "handles serialization with special characters" do
      # Arrange
      text_with_special = xmlText(value: ~c"<>&\"'", parents: [], pos: 1, language: [], type: :text)

      element =
        xmlElement(
          name: :test,
          content: [text_with_special],
          attributes: [],
          expanded_name: :test,
          namespace: {:xmlNamespace, [], []},
          parents: [],
          pos: 1,
          language: []
        )

      # Act
      {:ok, xml_string} = Xml.serialize(element)

      # Assert
      assert is_binary(xml_string)
      # Special characters should be escaped in the output
      assert xml_string =~ "test"
    end

    test "handles serialization with Unicode characters" do
      # Arrange
      unicode_text = xmlText(value: String.to_charlist("Hello 世界 🌍"), parents: [], pos: 1, language: [], type: :text)

      element =
        xmlElement(
          name: :unicode,
          content: [unicode_text],
          attributes: [],
          expanded_name: :unicode,
          namespace: {:xmlNamespace, [], []},
          parents: [],
          pos: 1,
          language: []
        )

      # Act
      {:ok, xml_string} = Xml.serialize(element)

      # Assert
      assert is_binary(xml_string)
      assert xml_string =~ "unicode"
      # Unicode characters should be preserved
      assert String.valid?(xml_string)
    end
  end

  describe "parse/1 edge cases" do
    test "handles XML with multiple root-level comments" do
      # Arrange
      xml_string = """
      <!-- Comment 1 -->
      <root>
        <!-- Comment 2 -->
        <child/>
      </root>
      <!-- Comment 3 -->
      """

      # Act
      {:ok, element} = Xml.parse(xml_string)

      # Assert
      assert Record.is_record(element, :xmlElement)
      assert xmlElement(element, :name) == :root
    end

    test "handles XML with processing instructions" do
      # Arrange
      xml_string = """
      <?xml version="1.0"?>
      <?xml-stylesheet type="text/xsl" href="style.xsl"?>
      <root>
        <child/>
      </root>
      """

      # Act
      {:ok, element} = Xml.parse(xml_string)

      # Assert
      assert Record.is_record(element, :xmlElement)
      assert xmlElement(element, :name) == :root
    end

    test "handles XML with DOCTYPE declaration" do
      # Arrange
      xml_string = """
      <?xml version="1.0"?>
      <!DOCTYPE root [
        <!ELEMENT root (child)>
        <!ELEMENT child (#PCDATA)>
      ]>
      <root>
        <child>text</child>
      </root>
      """

      # Act
      {:ok, element} = Xml.parse(xml_string)

      # Assert
      assert Record.is_record(element, :xmlElement)
      assert xmlElement(element, :name) == :root
    end
  end
end
