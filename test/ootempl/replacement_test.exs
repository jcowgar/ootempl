defmodule Ootempl.ReplacementTest do
  use ExUnit.Case, async: true

  import Ootempl.Xml
  alias Ootempl.Replacement

  doctest Ootempl.Replacement

  # Helper to wrap XML with namespace declaration
  defp word_xml(content) do
    ~s(<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">#{content}</w:document>)
  end

  # Helper to find w:t element and get its text nodes
  defp get_text_nodes(doc) do
    import Record

    # Find the w:t element within the document
    wt_elements = Ootempl.Xml.find_elements(doc, :"w:t")

    case wt_elements do
      [wt_element] ->
        # Get text nodes from the w:t element
        wt_element
        |> xmlElement(:content)
        |> Enum.filter(&is_record(&1, :xmlText))

      _ ->
        []
    end
  end

  # Helper to recursively extract all text from an element and its children
  # Only extracts text from <w:t> elements to avoid whitespace from XML formatting
  defp extract_all_text(element) do
    import Record

    element
    |> xmlElement(:content)
    |> Enum.flat_map(&extract_text_from_node/1)
    |> Enum.join()
  end

  defp extract_text_from_node(node) do
    import Record

    if is_record(node, :xmlElement) do
      extract_text_from_element(node)
    else
      [""]
    end
  end

  defp extract_text_from_element(element) do
    import Record

    name = xmlElement(element, :name)

    if name == :"w:t" or name == :t do
      extract_text_content(element)
    else
      [extract_all_text(element)]
    end
  end

  defp extract_text_content(element) do
    import Record

    element
    |> xmlElement(:content)
    |> Enum.map(&text_node_to_string/1)
  end

  defp text_node_to_string(node) do
    import Record

    if is_record(node, :xmlText) do
      node |> xmlText(:value) |> List.to_string()
    else
      ""
    end
  end

  describe "xml_escape/1" do
    test "escapes ampersand" do
      assert Replacement.xml_escape("Tom & Jerry") == "Tom &amp; Jerry"
    end

    test "escapes less than" do
      assert Replacement.xml_escape("x < y") == "x &lt; y"
    end

    test "escapes greater than" do
      assert Replacement.xml_escape("x > y") == "x &gt; y"
    end

    test "escapes double quote" do
      assert Replacement.xml_escape(~s(He said "hello")) == "He said &quot;hello&quot;"
    end

    test "escapes single quote" do
      assert Replacement.xml_escape("It's working") == "It&apos;s working"
    end

    test "escapes multiple special characters" do
      result = Replacement.xml_escape(~s(<tag attr="value">Tom & Jerry's</tag>))

      assert result ==
               "&lt;tag attr=&quot;value&quot;&gt;Tom &amp; Jerry&apos;s&lt;/tag&gt;"
    end

    test "handles empty string" do
      assert Replacement.xml_escape("") == ""
    end

    test "handles string with no special characters" do
      assert Replacement.xml_escape("Hello World") == "Hello World"
    end
  end

  describe "replace_in_text_node/2" do
    test "replaces simple placeholder" do
      # Arrange
      xml = word_xml("<w:t>Hello @name@</w:t>")
      {:ok, doc} = Ootempl.Xml.parse(xml)
      [text_node] = get_text_nodes(doc)
      data = %{"name" => "World"}

      # Act
      {:ok, result, []} = Replacement.replace_in_text_node(text_node, data)

      # Assert
      text = result |> xmlText(:value) |> List.to_string()
      assert text == "Hello World"
    end

    test "replaces multiple placeholders" do
      # Arrange
      xml = word_xml("<w:t>@greeting@ @name@!</w:t>")
      {:ok, doc} = Ootempl.Xml.parse(xml)
      [text_node] = get_text_nodes(doc)
      data = %{"greeting" => "Hello", "name" => "World"}

      # Act
      {:ok, result, []} = Replacement.replace_in_text_node(text_node, data)

      # Assert
      text = result |> xmlText(:value) |> List.to_string()
      assert text == "Hello World!"
    end

    test "replaces nested placeholder" do
      # Arrange
      xml = word_xml("<w:t>Customer: @customer.name@</w:t>")
      {:ok, doc} = Ootempl.Xml.parse(xml)
      [text_node] = get_text_nodes(doc)
      data = %{"customer" => %{"name" => "John Doe"}}

      # Act
      {:ok, result, []} = Replacement.replace_in_text_node(text_node, data)

      # Assert
      text = result |> xmlText(:value) |> List.to_string()
      assert text == "Customer: John Doe"
    end

    test "escapes XML special characters in replacement value" do
      # Arrange
      xml = word_xml("<w:t>Message: @msg@</w:t>")
      {:ok, doc} = Ootempl.Xml.parse(xml)
      [text_node] = get_text_nodes(doc)
      data = %{"msg" => "Tom & Jerry's <adventure>"}

      # Act
      {:ok, result, []} = Replacement.replace_in_text_node(text_node, data)

      # Assert
      text = result |> xmlText(:value) |> List.to_string()
      assert text == "Message: Tom &amp; Jerry&apos;s &lt;adventure&gt;"
    end

    test "returns error for missing placeholder" do
      # Arrange
      xml = word_xml("<w:t>Hello @missing@</w:t>")
      {:ok, doc} = Ootempl.Xml.parse(xml)
      [text_node] = get_text_nodes(doc)
      data = %{}

      # Act
      {:ok, original, errors} = Replacement.replace_in_text_node(text_node, data)

      # Assert
      assert original == text_node
      assert [{"@missing@", {:path_not_found, ["missing"]}}] = errors
    end

    test "collects multiple errors" do
      # Arrange
      xml = word_xml("<w:t>@missing1@ and @missing2@</w:t>")
      {:ok, doc} = Ootempl.Xml.parse(xml)
      [text_node] = get_text_nodes(doc)
      data = %{}

      # Act
      {:ok, original, errors} = Replacement.replace_in_text_node(text_node, data)

      # Assert
      assert original == text_node
      assert length(errors) == 2

      assert {"@missing1@", {:path_not_found, ["missing1"]}} in errors
      assert {"@missing2@", {:path_not_found, ["missing2"]}} in errors
    end

    test "handles empty replacement value" do
      # Arrange
      xml = word_xml("<w:t>Before @empty@ After</w:t>")
      {:ok, doc} = Ootempl.Xml.parse(xml)
      [text_node] = get_text_nodes(doc)
      data = %{"empty" => ""}

      # Act
      {:ok, result, []} = Replacement.replace_in_text_node(text_node, data)

      # Assert
      text = result |> xmlText(:value) |> List.to_string()
      assert text == "Before  After"
    end

    test "handles very long replacement value" do
      # Arrange
      xml = word_xml("<w:t>@long@</w:t>")
      {:ok, doc} = Ootempl.Xml.parse(xml)
      [text_node] = get_text_nodes(doc)
      long_value = String.duplicate("x", 1000)
      data = %{"long" => long_value}

      # Act
      {:ok, result, []} = Replacement.replace_in_text_node(text_node, data)

      # Assert
      text = result |> xmlText(:value) |> List.to_string()
      assert text == long_value
    end

    test "handles text node with only placeholder" do
      # Arrange
      xml = word_xml("<w:t>@name@</w:t>")
      {:ok, doc} = Ootempl.Xml.parse(xml)
      [text_node] = get_text_nodes(doc)
      data = %{"name" => "Complete"}

      # Act
      {:ok, result, []} = Replacement.replace_in_text_node(text_node, data)

      # Assert
      text = result |> xmlText(:value) |> List.to_string()
      assert text == "Complete"
    end

    test "handles case-insensitive placeholder matching" do
      # Arrange
      xml = word_xml("<w:t>Hello @NAME@</w:t>")
      {:ok, doc} = Ootempl.Xml.parse(xml)
      [text_node] = get_text_nodes(doc)
      data = %{"name" => "World"}

      # Act
      {:ok, result, []} = Replacement.replace_in_text_node(text_node, data)

      # Assert
      text = result |> xmlText(:value) |> List.to_string()
      assert text == "Hello World"
    end

    test "converts number to string" do
      # Arrange
      xml = word_xml("<w:t>Count: @count@</w:t>")
      {:ok, doc} = Ootempl.Xml.parse(xml)
      [text_node] = get_text_nodes(doc)
      data = %{"count" => 42}

      # Act
      {:ok, result, []} = Replacement.replace_in_text_node(text_node, data)

      # Assert
      text = result |> xmlText(:value) |> List.to_string()
      assert text == "Count: 42"
    end

    test "converts boolean to string" do
      # Arrange
      xml = word_xml("<w:t>Active: @active@</w:t>")
      {:ok, doc} = Ootempl.Xml.parse(xml)
      [text_node] = get_text_nodes(doc)
      data = %{"active" => true}

      # Act
      {:ok, result, []} = Replacement.replace_in_text_node(text_node, data)

      # Assert
      text = result |> xmlText(:value) |> List.to_string()
      assert text == "Active: true"
    end

    test "handles text with no placeholders" do
      # Arrange
      xml = word_xml("<w:t>Plain text</w:t>")
      {:ok, doc} = Ootempl.Xml.parse(xml)
      [text_node] = get_text_nodes(doc)
      data = %{}

      # Act
      {:ok, result, []} = Replacement.replace_in_text_node(text_node, data)

      # Assert
      text = result |> xmlText(:value) |> List.to_string()
      assert text == "Plain text"
    end
  end

  describe "replace_in_document/2" do
    test "replaces placeholder in simple document" do
      # Arrange
      xml = word_xml("<w:p><w:r><w:t>Hello @name@</w:t></w:r></w:p>")
      {:ok, doc} = Ootempl.Xml.parse(xml)
      data = %{"name" => "World"}

      # Act
      {:ok, result} = Replacement.replace_in_document(doc, data)

      # Assert
      [p] = Ootempl.Xml.find_elements(result, :"w:p")
      text = extract_all_text(p)
      assert text == "Hello World"
    end

    test "replaces multiple placeholders in document" do
      # Arrange
      xml =
        word_xml("""
        <w:body>
          <w:p><w:r><w:t>Hello @name@</w:t></w:r></w:p>
          <w:p><w:r><w:t>Your email is @email@</w:t></w:r></w:p>
        </w:body>
        """)

      {:ok, doc} = Ootempl.Xml.parse(xml)
      data = %{"name" => "John", "email" => "john@example.com"}

      # Act
      {:ok, result} = Replacement.replace_in_document(doc, data)

      # Assert
      [body] = Ootempl.Xml.find_elements(result, :"w:body")
      paragraphs = Ootempl.Xml.find_elements(body, :"w:p")
      assert length(paragraphs) == 2

      [p1, p2] = paragraphs
      assert extract_all_text(p1) == "Hello John"
      assert extract_all_text(p2) == "Your email is john@example.com"
    end

    test "preserves formatting during replacement" do
      # Arrange
      xml =
        word_xml("""
        <w:p>
          <w:r>
            <w:rPr>
              <w:b/>
              <w:i/>
            </w:rPr>
            <w:t>Hello @name@</w:t>
          </w:r>
        </w:p>
        """)

      {:ok, doc} = Ootempl.Xml.parse(xml)
      data = %{"name" => "World"}

      # Act
      {:ok, result} = Replacement.replace_in_document(doc, data)

      # Assert
      # Check that formatting properties still exist
      [p] = Ootempl.Xml.find_elements(result, :"w:p")
      runs = Ootempl.Xml.find_elements(p, :"w:r")
      assert length(runs) == 1
      [run] = runs

      # Check for run properties
      props = Ootempl.Xml.find_elements(run, :"w:rPr")
      assert length(props) == 1

      # Check text was replaced
      text = extract_all_text(p)
      assert text == "Hello World"
    end

    test "returns error for missing placeholder" do
      # Arrange
      xml = word_xml("<w:p><w:r><w:t>Hello @missing@</w:t></w:r></w:p>")
      {:ok, doc} = Ootempl.Xml.parse(xml)
      data = %{}

      # Act
      {:error, error} = Replacement.replace_in_document(doc, data)

      # Assert
      assert %Ootempl.PlaceholderError{} = error
      assert length(error.placeholders) == 1
      assert %{placeholder: "@missing@", reason: {:path_not_found, ["missing"]}} in error.placeholders
    end

    test "collects all errors from multiple placeholders" do
      # Arrange
      xml =
        word_xml("""
        <w:body>
          <w:p><w:r><w:t>Hello @missing1@</w:t></w:r></w:p>
          <w:p><w:r><w:t>Goodbye @missing2@</w:t></w:r></w:p>
        </w:body>
        """)

      {:ok, doc} = Ootempl.Xml.parse(xml)
      data = %{}

      # Act
      {:error, error} = Replacement.replace_in_document(doc, data)

      # Assert
      assert %Ootempl.PlaceholderError{} = error
      assert length(error.placeholders) == 2

      assert %{placeholder: "@missing1@", reason: {:path_not_found, ["missing1"]}} in error.placeholders
      assert %{placeholder: "@missing2@", reason: {:path_not_found, ["missing2"]}} in error.placeholders
    end

    test "handles nested data access" do
      # Arrange
      xml =
        word_xml(
          "<w:p><w:r><w:t>Customer: @customer.name@, Email: @customer.email@</w:t></w:r></w:p>"
        )

      {:ok, doc} = Ootempl.Xml.parse(xml)
      data = %{"customer" => %{"name" => "John Doe", "email" => "john@example.com"}}

      # Act
      {:ok, result} = Replacement.replace_in_document(doc, data)

      # Assert
      [p] = Ootempl.Xml.find_elements(result, :"w:p")
      text = extract_all_text(p)
      assert text == "Customer: John Doe, Email: john@example.com"
    end

    test "handles list index access" do
      # Arrange
      xml = word_xml("<w:p><w:r><w:t>First item: @items.0.name@</w:t></w:r></w:p>")
      {:ok, doc} = Ootempl.Xml.parse(xml)
      data = %{"items" => [%{"name" => "Apple"}, %{"name" => "Banana"}]}

      # Act
      {:ok, result} = Replacement.replace_in_document(doc, data)

      # Assert
      [p] = Ootempl.Xml.find_elements(result, :"w:p")
      text = extract_all_text(p)
      assert text == "First item: Apple"
    end

    test "handles empty document" do
      # Arrange
      xml = word_xml("")
      {:ok, doc} = Ootempl.Xml.parse(xml)
      data = %{}

      # Act
      {:ok, result} = Replacement.replace_in_document(doc, data)

      # Assert
      assert Ootempl.Xml.element_name(result) == "w:document"
    end

    test "handles document with no placeholders" do
      # Arrange
      xml = word_xml("<w:p><w:r><w:t>Plain text</w:t></w:r></w:p>")
      {:ok, doc} = Ootempl.Xml.parse(xml)
      data = %{"unused" => "value"}

      # Act
      {:ok, result} = Replacement.replace_in_document(doc, data)

      # Assert
      [p] = Ootempl.Xml.find_elements(result, :"w:p")
      text = extract_all_text(p)
      assert text == "Plain text"
    end
  end

  describe "integration with real Word XML structure" do
    test "handles complex Word document structure" do
      # Arrange
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:body>
          <w:p>
            <w:pPr>
              <w:pStyle w:val="Normal"/>
            </w:pPr>
            <w:r>
              <w:rPr>
                <w:b/>
                <w:sz w:val="24"/>
              </w:rPr>
              <w:t>Dear @customer.name@,</w:t>
            </w:r>
          </w:p>
          <w:p>
            <w:r>
              <w:t>Your order #@order.id@ has been shipped.</w:t>
            </w:r>
          </w:p>
        </w:body>
      </w:document>
      """

      {:ok, doc} = Ootempl.Xml.parse(xml)

      data = %{
        "customer" => %{"name" => "Jane Smith"},
        "order" => %{"id" => "12345"}
      }

      # Act
      {:ok, result} = Replacement.replace_in_document(doc, data)

      # Assert
      body = Ootempl.Xml.find_elements(result, :"w:body") |> List.first()
      paragraphs = Ootempl.Xml.find_elements(body, :"w:p")
      assert length(paragraphs) == 2

      [p1, p2] = paragraphs
      assert extract_all_text(p1) == "Dear Jane Smith,"
      assert extract_all_text(p2) == "Your order #12345 has been shipped."
    end
  end

  describe "edge cases" do
    test "handles replacement with newline characters" do
      # Arrange
      xml = word_xml("<w:t>Address: @address@</w:t>")
      {:ok, doc} = Ootempl.Xml.parse(xml)
      [text_node] = get_text_nodes(doc)
      data = %{"address" => "123 Main St\nApt 4B"}

      # Act
      {:ok, result, []} = Replacement.replace_in_text_node(text_node, data)

      # Assert
      text = result |> xmlText(:value) |> List.to_string()
      assert text == "Address: 123 Main St\nApt 4B"
    end

    test "handles Unicode characters in replacement" do
      # Arrange
      xml = word_xml("<w:t>Name: @name@</w:t>")
      {:ok, doc} = Ootempl.Xml.parse(xml)
      [text_node] = get_text_nodes(doc)
      data = %{"name" => "François Müller 日本"}

      # Act
      {:ok, result, []} = Replacement.replace_in_text_node(text_node, data)

      # Assert
      text = result |> xmlText(:value) |> List.to_string()
      assert text == "Name: François Müller 日本"
    end

    test "handles malformed placeholder (no closing @)" do
      # Arrange
      xml = word_xml("<w:t>Hello @incomplete</w:t>")
      {:ok, doc} = Ootempl.Xml.parse(xml)
      [text_node] = get_text_nodes(doc)
      data = %{"incomplete" => "value"}

      # Act
      {:ok, result, []} = Replacement.replace_in_text_node(text_node, data)

      # Assert - malformed placeholder should not be detected, text unchanged
      text = result |> xmlText(:value) |> List.to_string()
      assert text == "Hello @incomplete"
    end

    test "handles nil value in data" do
      # Arrange
      xml = word_xml("<w:t>Value: @nullable@</w:t>")
      {:ok, doc} = Ootempl.Xml.parse(xml)
      [text_node] = get_text_nodes(doc)
      data = %{"nullable" => nil}

      # Act
      {:ok, _original, errors} = Replacement.replace_in_text_node(text_node, data)

      # Assert
      assert [{"@nullable@", :nil_value}] = errors
    end

    test "handles error with index out of bounds" do
      # Arrange
      xml = word_xml("<w:t>Item: @items.5.name@</w:t>")
      {:ok, doc} = Ootempl.Xml.parse(xml)
      [text_node] = get_text_nodes(doc)
      data = %{"items" => [%{"name" => "Only one item"}]}

      # Act
      {:ok, _original, errors} = Replacement.replace_in_text_node(text_node, data)

      # Assert
      assert [{"@items.5.name@", {:index_out_of_bounds, 5, 1}}] = errors
    end
  end
end
