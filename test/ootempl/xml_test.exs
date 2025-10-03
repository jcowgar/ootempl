defmodule Ootempl.XmlTest do
  use ExUnit.Case, async: true

  import Ootempl.Xml

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
