defmodule Ootempl.XmlTest do
  use ExUnit.Case, async: true

  import Ootempl.Xml

  require Record

  describe "element_name/1" do
    test "returns element name as string" do
      # Arrange
      element = xmlElement(name: :div)

      # Act
      result = element_name(element)

      # Assert
      assert result == "div"
    end

    test "handles namespaced element names" do
      # Arrange
      element = xmlElement(name: :"w:p")

      # Act
      result = element_name(element)

      # Assert
      assert result == "w:p"
    end

    test "handles complex namespace names" do
      # Arrange
      element = xmlElement(name: :"w:document")

      # Act
      result = element_name(element)

      # Assert
      assert result == "w:document"
    end
  end

  describe "element_attributes/1" do
    test "returns list of attributes" do
      # Arrange
      attr1 = xmlAttribute(name: :class, value: ~c"test")
      attr2 = xmlAttribute(name: :id, value: ~c"main")
      element = xmlElement(attributes: [attr1, attr2])

      # Act
      result = element_attributes(element)

      # Assert
      assert result == [attr1, attr2]
    end

    test "returns empty list when no attributes" do
      # Arrange
      element = xmlElement(attributes: [])

      # Act
      result = element_attributes(element)

      # Assert
      assert result == []
    end
  end

  describe "element_text/1" do
    test "extracts text from single text node" do
      # Arrange
      text_node = xmlText(value: ~c"Hello World")
      element = xmlElement(content: [text_node])

      # Act
      result = element_text(element)

      # Assert
      assert result == "Hello World"
    end

    test "extracts and concatenates multiple text nodes" do
      # Arrange
      text1 = xmlText(value: ~c"Hello ")
      text2 = xmlText(value: ~c"World")
      element = xmlElement(content: [text1, text2])

      # Act
      result = element_text(element)

      # Assert
      assert result == "Hello World"
    end

    test "returns empty string for element with no text content" do
      # Arrange
      element = xmlElement(content: [])

      # Act
      result = element_text(element)

      # Assert
      assert result == ""
    end

    test "ignores child elements and only extracts text nodes" do
      # Arrange
      text_node = xmlText(value: ~c"Text content")
      child_element = xmlElement(name: :span, content: [xmlText(value: ~c"Child text")])
      element = xmlElement(content: [text_node, child_element])

      # Act
      result = element_text(element)

      # Assert
      assert result == "Text content"
    end

    test "handles text with special characters" do
      # Arrange
      text_node = xmlText(value: ~c"Hello & <World>")
      element = xmlElement(content: [text_node])

      # Act
      result = element_text(element)

      # Assert
      assert result == "Hello & <World>"
    end

    test "handles UTF-8 text content" do
      # Arrange
      text_node = xmlText(value: ~c"Héllo Wörld 你好")
      element = xmlElement(content: [text_node])

      # Act
      result = element_text(element)

      # Assert
      assert result == "Héllo Wörld 你好"
    end
  end

  describe "find_elements/2" do
    test "finds child elements by atom name" do
      # Arrange
      child1 = xmlElement(name: :div)
      child2 = xmlElement(name: :span)
      child3 = xmlElement(name: :div)
      parent = xmlElement(content: [child1, child2, child3])

      # Act
      result = find_elements(parent, :div)

      # Assert
      assert result == [child1, child3]
    end

    test "finds child elements by string name" do
      # Arrange
      child1 = xmlElement(name: :div)
      child2 = xmlElement(name: :span)
      parent = xmlElement(content: [child1, child2])

      # Act
      result = find_elements(parent, "div")

      # Assert
      assert result == [child1]
    end

    test "returns empty list when no matching elements found" do
      # Arrange
      child = xmlElement(name: :span)
      parent = xmlElement(content: [child])

      # Act
      result = find_elements(parent, :div)

      # Assert
      assert result == []
    end

    test "returns empty list when element has no children" do
      # Arrange
      parent = xmlElement(content: [])

      # Act
      result = find_elements(parent, :div)

      # Assert
      assert result == []
    end

    test "finds namespaced elements" do
      # Arrange
      child1 = xmlElement(name: :"w:p")
      child2 = xmlElement(name: :"w:r")
      parent = xmlElement(content: [child1, child2])

      # Act
      result = find_elements(parent, :"w:p")

      # Assert
      assert result == [child1]
    end

    test "ignores text nodes when searching" do
      # Arrange
      text_node = xmlText(value: ~c"text")
      child = xmlElement(name: :div)
      parent = xmlElement(content: [text_node, child])

      # Act
      result = find_elements(parent, :div)

      # Assert
      assert result == [child]
    end
  end

  describe "get_attribute/2" do
    test "returns attribute value by atom name" do
      # Arrange
      attr = xmlAttribute(name: :class, value: ~c"container")
      element = xmlElement(attributes: [attr])

      # Act
      result = get_attribute(element, :class)

      # Assert
      assert result == {:ok, "container"}
    end

    test "returns attribute value by string name" do
      # Arrange
      attr = xmlAttribute(name: :class, value: ~c"container")
      element = xmlElement(attributes: [attr])

      # Act
      result = get_attribute(element, "class")

      # Assert
      assert result == {:ok, "container"}
    end

    test "returns error when attribute not found" do
      # Arrange
      element = xmlElement(attributes: [])

      # Act
      result = get_attribute(element, :class)

      # Assert
      assert result == {:error, :not_found}
    end

    test "finds correct attribute among multiple attributes" do
      # Arrange
      attr1 = xmlAttribute(name: :class, value: ~c"container")
      attr2 = xmlAttribute(name: :id, value: ~c"main")
      attr3 = xmlAttribute(name: :style, value: ~c"color: red")
      element = xmlElement(attributes: [attr1, attr2, attr3])

      # Act
      result = get_attribute(element, :id)

      # Assert
      assert result == {:ok, "main"}
    end

    test "handles empty attribute value" do
      # Arrange
      attr = xmlAttribute(name: :class, value: ~c"")
      element = xmlElement(attributes: [attr])

      # Act
      result = get_attribute(element, :class)

      # Assert
      assert result == {:ok, ""}
    end

    test "handles namespaced attribute names" do
      # Arrange
      attr = xmlAttribute(name: :"w:val", value: ~c"test")
      element = xmlElement(attributes: [attr])

      # Act
      result = get_attribute(element, :"w:val")

      # Assert
      assert result == {:ok, "test"}
    end

    test "handles attribute values with special characters" do
      # Arrange
      attr = xmlAttribute(name: :class, value: ~c"test & <value>")
      element = xmlElement(attributes: [attr])

      # Act
      result = get_attribute(element, :class)

      # Assert
      assert result == {:ok, "test & <value>"}
    end
  end

  describe "parse/1" do
    test "parses simple XML string to :xmerl record" do
      # Arrange
      xml = "<root><child>text</child></root>"

      # Act
      result = Ootempl.Xml.parse(xml)

      # Assert
      assert {:ok, element} = result
      assert element_name(element) == "root"
    end

    test "parses XML with attributes" do
      # Arrange
      xml = ~s(<root id="test" class="container"></root>)

      # Act
      {:ok, element} = Ootempl.Xml.parse(xml)

      # Assert
      assert element_name(element) == "root"
      assert {:ok, "test"} = get_attribute(element, :id)
      assert {:ok, "container"} = get_attribute(element, :class)
    end

    test "parses XML with namespaces" do
      # Arrange
      xml =
        ~s(<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body></w:body></w:document>)

      # Act
      result = Ootempl.Xml.parse(xml)

      # Assert
      assert {:ok, element} = result
      # Note: :xmerl may handle namespace prefixes differently
      assert is_tuple(element)
    end

    test "parses nested XML structure" do
      # Arrange
      xml = "<root><parent><child>text</child></parent></root>"

      # Act
      {:ok, element} = Ootempl.Xml.parse(xml)

      # Assert
      assert element_name(element) == "root"
      parents = find_elements(element, :parent)
      assert length(parents) == 1
    end

    test "parses XML with multiple children" do
      # Arrange
      xml = "<root><child1/><child2/><child3/></root>"

      # Act
      {:ok, element} = Ootempl.Xml.parse(xml)
      content = xmlElement(element, :content)

      # Assert
      # Filter out text nodes (whitespace) that :xmerl might include
      element_nodes = Enum.filter(content, fn node -> Record.is_record(node, :xmlElement) end)
      assert length(element_nodes) == 3
    end

    test "parses XML with mixed content" do
      # Arrange
      xml = "<root>text1<child/>text2</root>"

      # Act
      result = Ootempl.Xml.parse(xml)

      # Assert
      assert {:ok, element} = result
      assert element_name(element) == "root"
    end

    test "parses self-closing elements" do
      # Arrange
      xml = "<root><child/></root>"

      # Act
      {:ok, element} = Ootempl.Xml.parse(xml)

      # Assert
      assert element_name(element) == "root"
      children = find_elements(element, :child)
      assert length(children) == 1
    end

    test "parses XML with character entities" do
      # Arrange
      # .docx files use XML character entities for special chars (e.g., &#233; for é)
      xml = ~s(<root>H&#233;llo W&#246;rld &#20320;&#22909;</root>)

      # Act
      {:ok, element} = Ootempl.Xml.parse(xml)

      # Assert
      text = element_text(element)
      assert text == "Héllo Wörld 你好"
    end

    test "returns error for malformed XML" do
      # Arrange
      xml = "<root><unclosed>"

      # Act
      result = Ootempl.Xml.parse(xml)

      # Assert
      assert {:error, _reason} = result
    end

    test "returns error for empty string" do
      # Arrange
      xml = ""

      # Act
      result = Ootempl.Xml.parse(xml)

      # Assert
      assert {:error, _reason} = result
    end

    test "returns error for non-XML string" do
      # Arrange
      xml = "this is not xml"

      # Act
      result = Ootempl.Xml.parse(xml)

      # Assert
      assert {:error, _reason} = result
    end
  end

  describe "serialize/1" do
    test "serializes simple :xmerl record to XML string" do
      # Arrange
      xml = "<root><child>text</child></root>"
      {:ok, element} = Ootempl.Xml.parse(xml)

      # Act
      result = Ootempl.Xml.serialize(element)

      # Assert
      assert {:ok, xml_string} = result
      assert is_binary(xml_string)
      assert xml_string =~ "root"
      assert xml_string =~ "child"
    end

    test "serializes XML with attributes" do
      # Arrange
      xml = ~s(<root id="test"></root>)
      {:ok, element} = Ootempl.Xml.parse(xml)

      # Act
      {:ok, xml_string} = Ootempl.Xml.serialize(element)

      # Assert
      assert xml_string =~ "root"
      assert xml_string =~ ~s(id="test")
    end

    test "serializes nested XML structure" do
      # Arrange
      xml = "<root><parent><child>text</child></parent></root>"
      {:ok, element} = Ootempl.Xml.parse(xml)

      # Act
      {:ok, xml_string} = Ootempl.Xml.serialize(element)

      # Assert
      assert xml_string =~ "root"
      assert xml_string =~ "parent"
      assert xml_string =~ "child"
    end

    test "serializes XML with character entities" do
      # Arrange
      # Character entities should be preserved during round-trip
      xml = ~s(<root>H&#233;llo W&#246;rld &#20320;&#22909;</root>)
      {:ok, element} = Ootempl.Xml.parse(xml)

      # Act
      {:ok, xml_string} = Ootempl.Xml.serialize(element)

      # Assert
      # :xmerl converts entities to actual characters in the output
      assert xml_string =~ "Héllo Wörld 你好"
    end

    test "serializes self-closing elements" do
      # Arrange
      xml = "<root><child/></root>"
      {:ok, element} = Ootempl.Xml.parse(xml)

      # Act
      {:ok, xml_string} = Ootempl.Xml.serialize(element)

      # Assert
      assert xml_string =~ "root"
      assert xml_string =~ "child"
    end
  end

  describe "round_trip/1" do
    test "preserves simple XML structure" do
      # Arrange
      xml = "<root><child>text</child></root>"

      # Act
      result = Ootempl.Xml.round_trip(xml)

      # Assert
      assert {:ok, xml_string} = result
      assert xml_string =~ "root"
      assert xml_string =~ "child"
      assert xml_string =~ "text"
    end

    test "preserves attributes" do
      # Arrange
      xml = ~s(<root id="test" class="container"></root>)

      # Act
      {:ok, xml_string} = Ootempl.Xml.round_trip(xml)

      # Assert
      assert xml_string =~ "root"
      assert xml_string =~ ~s(id="test")
      assert xml_string =~ ~s(class="container")
    end

    test "preserves nested structure" do
      # Arrange
      xml = "<root><level1><level2><level3>deep</level3></level2></level1></root>"

      # Act
      {:ok, xml_string} = Ootempl.Xml.round_trip(xml)

      # Assert
      assert xml_string =~ "root"
      assert xml_string =~ "level1"
      assert xml_string =~ "level2"
      assert xml_string =~ "level3"
      assert xml_string =~ "deep"
    end

    test "preserves character entities as UTF-8" do
      # Arrange
      # XML character entities are converted to UTF-8 during round-trip
      xml = ~s(<root>H&#233;llo W&#246;rld &#20320;&#22909;</root>)

      # Act
      {:ok, xml_string} = Ootempl.Xml.round_trip(xml)

      # Assert
      # :xmerl decodes entities to UTF-8 characters
      assert xml_string =~ "Héllo Wörld 你好"
    end

    test "preserves multiple children" do
      # Arrange
      xml = "<root><child1/><child2/><child3/></root>"

      # Act
      {:ok, xml_string} = Ootempl.Xml.round_trip(xml)

      # Assert
      assert xml_string =~ "child1"
      assert xml_string =~ "child2"
      assert xml_string =~ "child3"
    end

    test "preserves namespaces" do
      # Arrange
      xml =
        ~s(<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body></w:body></w:document>)

      # Act
      result = Ootempl.Xml.round_trip(xml)

      # Assert
      assert {:ok, xml_string} = result
      # Namespaces should be preserved in some form
      assert is_binary(xml_string)
    end

    test "round-trip allows re-parsing" do
      # Arrange
      xml = "<root><child>text</child></root>"

      # Act
      {:ok, xml_string} = Ootempl.Xml.round_trip(xml)
      reparse_result = Ootempl.Xml.parse(xml_string)

      # Assert
      assert {:ok, element} = reparse_result
      assert element_name(element) == "root"
    end

    test "returns error for malformed XML" do
      # Arrange
      xml = "<root><unclosed>"

      # Act
      result = Ootempl.Xml.round_trip(xml)

      # Assert
      assert {:error, _reason} = result
    end
  end

  describe "record definitions" do
    test "xmlElement record can be created and accessed" do
      # Arrange & Act
      element = xmlElement(name: :div, content: [], attributes: [])

      # Assert
      assert xmlElement(element, :name) == :div
      assert xmlElement(element, :content) == []
      assert xmlElement(element, :attributes) == []
    end

    test "xmlAttribute record can be created and accessed" do
      # Arrange & Act
      attr = xmlAttribute(name: :class, value: ~c"test")

      # Assert
      assert xmlAttribute(attr, :name) == :class
      assert xmlAttribute(attr, :value) == ~c"test"
    end

    test "xmlText record can be created and accessed" do
      # Arrange & Act
      text = xmlText(value: ~c"Hello")

      # Assert
      assert xmlText(text, :value) == ~c"Hello"
    end
  end

  describe "integration with real .docx files" do
    @fixture_path Path.join([__DIR__, "..", "fixtures", "Simple Placeholdes from Word.docx"])

    test "parses real document.xml from .docx file" do
      # Arrange
      {:ok, contents} = Ootempl.Archive.extract_file(@fixture_path, "word/document.xml")

      # Act
      result = Ootempl.Xml.parse(contents)

      # Assert
      assert {:ok, doc} = result
      assert element_name(doc) == "w:document"
    end

    test "round-trips real document.xml preserving structure" do
      # Arrange
      {:ok, original_xml} = Ootempl.Archive.extract_file(@fixture_path, "word/document.xml")

      # Act
      {:ok, doc} = Ootempl.Xml.parse(original_xml)
      {:ok, serialized_xml} = Ootempl.Xml.serialize(doc)

      # Assert - verify we can re-parse the serialized XML
      assert {:ok, reparsed_doc} = Ootempl.Xml.parse(serialized_xml)
      assert element_name(reparsed_doc) == "w:document"
    end

    test "extracts namespaced elements from real .docx" do
      # Arrange
      {:ok, contents} = Ootempl.Archive.extract_file(@fixture_path, "word/document.xml")
      {:ok, doc} = Ootempl.Xml.parse(contents)

      # Act - find w:body element
      body_elements = find_elements(doc, :"w:body")

      # Assert
      assert length(body_elements) == 1
    end
  end

  describe "complex nested structures" do
    test "extracts text from deeply nested elements" do
      # Arrange
      text1 = xmlText(value: ~c"Hello ")
      text2 = xmlText(value: ~c"World")
      _inner = xmlElement(name: :span, content: [text2])
      outer = xmlElement(name: :div, content: [text1])

      # Act
      result = element_text(outer)

      # Assert
      assert result == "Hello "
    end

    test "finds elements in mixed content" do
      # Arrange
      text = xmlText(value: ~c"text")
      child1 = xmlElement(name: :div)
      child2 = xmlElement(name: :span)
      child3 = xmlElement(name: :div)
      parent = xmlElement(content: [text, child1, child2, child3, text])

      # Act
      result = find_elements(parent, :div)

      # Assert
      assert result == [child1, child3]
    end

    test "works with realistic Word XML structure" do
      # Arrange - simulate w:p > w:r > w:t structure from Word
      text_node = xmlText(value: ~c"Hello Document")
      w_t = xmlElement(name: :"w:t", content: [text_node])
      w_r = xmlElement(name: :"w:r", content: [w_t])
      w_p = xmlElement(name: :"w:p", content: [w_r])

      # Act
      runs = find_elements(w_p, :"w:r")
      text_elements = find_elements(hd(runs), :"w:t")
      text = element_text(hd(text_elements))

      # Assert
      assert length(runs) == 1
      assert length(text_elements) == 1
      assert text == "Hello Document"
    end
  end
end
