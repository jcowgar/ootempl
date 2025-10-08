defmodule Ootempl.ConditionalTest do
  use ExUnit.Case, async: true

  import Ootempl.Xml

  alias Ootempl.Conditional

  require Record

  doctest Conditional

  describe "detect_conditionals/1" do
    test "detects @if:variable@ markers" do
      # Arrange
      text = "Hello @if:name@ world"

      # Act
      result = Conditional.detect_conditionals(text)

      # Assert
      assert [%{type: :if, condition: "name", path: ["name"], position: 6}] = result
    end

    test "detects @endif@ markers" do
      # Arrange
      text = "Hello @endif@ world"

      # Act
      result = Conditional.detect_conditionals(text)

      # Assert
      assert [%{type: :endif, condition: nil, path: nil, position: 6}] = result
    end

    test "detects both @if@ and @endif@ markers in order" do
      # Arrange
      text = "@if:active@content@endif@"

      # Act
      result = Conditional.detect_conditionals(text)

      # Assert
      assert [
               %{type: :if, condition: "active", path: ["active"], position: 0},
               %{type: :endif, condition: nil, path: nil, position: 18}
             ] = result
    end

    test "detects case-insensitive @IF:variable@ markers" do
      # Arrange
      text = "@IF:name@ content"

      # Act
      result = Conditional.detect_conditionals(text)

      # Assert
      assert [%{type: :if, condition: "name", path: ["name"], position: 0}] = result
    end

    test "detects case-insensitive @If:Variable@ markers" do
      # Arrange
      text = "@If:UserName@ content"

      # Act
      result = Conditional.detect_conditionals(text)

      # Assert
      assert [%{type: :if, condition: "UserName", path: ["UserName"], position: 0}] = result
    end

    test "detects case-insensitive @ENDIF@ markers" do
      # Arrange
      text = "@if:name@ @ENDIF@"

      # Act
      result = Conditional.detect_conditionals(text)

      # Assert
      assert [
               %{type: :if, condition: "name", path: ["name"], position: 0},
               %{type: :endif, condition: nil, path: nil, position: 10}
             ] = result
    end

    test "detects nested data paths in conditions" do
      # Arrange
      text = "@if:customer.active@"

      # Act
      result = Conditional.detect_conditionals(text)

      # Assert
      assert [
               %{type: :if, condition: "customer.active", path: ["customer", "active"], position: 0}
             ] = result
    end

    test "detects deeply nested data paths" do
      # Arrange
      text = "@if:user.profile.name@"

      # Act
      result = Conditional.detect_conditionals(text)

      # Assert
      assert [
               %{
                 type: :if,
                 condition: "user.profile.name",
                 path: ["user", "profile", "name"],
                 position: 0
               }
             ] = result
    end

    test "returns empty list when no markers present" do
      # Arrange
      text = "No markers in this text"

      # Act
      result = Conditional.detect_conditionals(text)

      # Assert
      assert [] = result
    end

    test "handles empty text" do
      # Arrange
      text = ""

      # Act
      result = Conditional.detect_conditionals(text)

      # Assert
      assert [] = result
    end

    test "detects multiple consecutive conditionals" do
      # Arrange
      text = "@if:first@@endif@@if:second@@endif@"

      # Act
      result = Conditional.detect_conditionals(text)

      # Assert
      assert [
               %{type: :if, condition: "first", position: 0},
               %{type: :endif, position: 10},
               %{type: :if, condition: "second", position: 17},
               %{type: :endif, position: 28}
             ] = result
    end

    test "handles variables starting with underscore" do
      # Arrange
      text = "@if:_private@"

      # Act
      result = Conditional.detect_conditionals(text)

      # Assert
      assert [%{type: :if, condition: "_private", path: ["_private"], position: 0}] = result
    end

    test "handles variables with numbers" do
      # Arrange
      text = "@if:user123@"

      # Act
      result = Conditional.detect_conditionals(text)

      # Assert
      assert [%{type: :if, condition: "user123", path: ["user123"], position: 0}] = result
    end

    test "ignores malformed @if:@ without variable" do
      # Arrange
      text = "@if:@ content"

      # Act
      result = Conditional.detect_conditionals(text)

      # Assert
      assert [] = result
    end

    test "ignores @if@ without variable starting with number" do
      # Arrange
      text = "@if:123name@ content"

      # Act
      result = Conditional.detect_conditionals(text)

      # Assert
      assert [] = result
    end

    test "ignores incomplete markers without closing @" do
      # Arrange
      text = "@if:name content @endif"

      # Act
      result = Conditional.detect_conditionals(text)

      # Assert
      assert [] = result
    end

    test "detects @else@ markers" do
      # Arrange
      text = "Hello @else@ world"

      # Act
      result = Conditional.detect_conditionals(text)

      # Assert
      assert [%{type: :else, condition: nil, path: nil, position: 6}] = result
    end

    test "detects @if@, @else@, and @endif@ markers in order" do
      # Arrange
      text = "@if:show@yes@else@no@endif@"

      # Act
      result = Conditional.detect_conditionals(text)

      # Assert
      assert [
               %{type: :if, condition: "show", path: ["show"], position: 0},
               %{type: :else, condition: nil, path: nil, position: 12},
               %{type: :endif, condition: nil, path: nil, position: 20}
             ] = result
    end

    test "detects case-insensitive @ELSE@ markers" do
      # Arrange
      text = "@if:name@ @ELSE@ @endif@"

      # Act
      result = Conditional.detect_conditionals(text)

      # Assert
      assert [
               %{type: :if, condition: "name", path: ["name"], position: 0},
               %{type: :else, condition: nil, path: nil, position: 10},
               %{type: :endif, condition: nil, path: nil, position: 17}
             ] = result
    end

    test "detects @Else@ with mixed case" do
      # Arrange
      text = "@Else@"

      # Act
      result = Conditional.detect_conditionals(text)

      # Assert
      assert [%{type: :else, condition: nil, path: nil, position: 0}] = result
    end
  end

  describe "validate_pairs/1" do
    test "validates properly matched single pair" do
      # Arrange
      conditionals = [
        %{type: :if, condition: "name", path: ["name"], position: 0},
        %{type: :endif, condition: nil, path: nil, position: 10}
      ]

      # Act
      result = Conditional.validate_pairs(conditionals)

      # Assert
      assert :ok = result
    end

    test "validates properly matched multiple pairs" do
      # Arrange
      conditionals = [
        %{type: :if, condition: "first", path: ["first"], position: 0},
        %{type: :endif, condition: nil, path: nil, position: 12},
        %{type: :if, condition: "second", path: ["second"], position: 20},
        %{type: :endif, condition: nil, path: nil, position: 33}
      ]

      # Act
      result = Conditional.validate_pairs(conditionals)

      # Assert
      assert :ok = result
    end

    test "validates empty list" do
      # Arrange
      conditionals = []

      # Act
      result = Conditional.validate_pairs(conditionals)

      # Assert
      assert :ok = result
    end

    test "returns error for unmatched @if@" do
      # Arrange
      conditionals = [
        %{type: :if, condition: "name", path: ["name"], position: 5}
      ]

      # Act
      result = Conditional.validate_pairs(conditionals)

      # Assert
      assert {:error, "Unmatched @if:name@ at position 5"} = result
    end

    test "returns error for orphan @endif@" do
      # Arrange
      conditionals = [
        %{type: :endif, condition: nil, path: nil, position: 10}
      ]

      # Act
      result = Conditional.validate_pairs(conditionals)

      # Assert
      assert {:error, "Orphan @endif@ at position 10 (no matching @if@)"} = result
    end

    test "returns error for @endif@ before @if@" do
      # Arrange
      conditionals = [
        %{type: :endif, condition: nil, path: nil, position: 0},
        %{type: :if, condition: "name", path: ["name"], position: 10}
      ]

      # Act
      result = Conditional.validate_pairs(conditionals)

      # Assert
      assert {:error, "Orphan @endif@ at position 0 (no matching @if@)"} = result
    end

    test "returns error for multiple unmatched @if@ markers" do
      # Arrange
      conditionals = [
        %{type: :if, condition: "first", path: ["first"], position: 0},
        %{type: :if, condition: "second", path: ["second"], position: 12},
        %{type: :endif, condition: nil, path: nil, position: 25}
      ]

      # Act
      result = Conditional.validate_pairs(conditionals)

      # Assert
      assert {:error, "Unmatched @if:first@ at position 0"} = result
    end

    test "detects first orphan @endif@ in sequence" do
      # Arrange
      conditionals = [
        %{type: :if, condition: "name", path: ["name"], position: 0},
        %{type: :endif, condition: nil, path: nil, position: 10},
        %{type: :endif, condition: nil, path: nil, position: 18}
      ]

      # Act
      result = Conditional.validate_pairs(conditionals)

      # Assert
      assert {:error, "Orphan @endif@ at position 18 (no matching @if@)"} = result
    end

    test "validates properly matched if/else/endif triplet" do
      # Arrange
      conditionals = [
        %{type: :if, condition: "show", path: ["show"], position: 0},
        %{type: :else, condition: nil, path: nil, position: 13},
        %{type: :endif, condition: nil, path: nil, position: 22}
      ]

      # Act
      result = Conditional.validate_pairs(conditionals)

      # Assert
      assert :ok = result
    end

    test "returns error for orphan @else@ without @if@" do
      # Arrange
      conditionals = [
        %{type: :else, condition: nil, path: nil, position: 5}
      ]

      # Act
      result = Conditional.validate_pairs(conditionals)

      # Assert
      assert {:error, "Orphan @else@ at position 5 (no matching @if@)"} = result
    end

    test "returns error for multiple @else@ in same block" do
      # Arrange
      conditionals = [
        %{type: :if, condition: "x", path: ["x"], position: 0},
        %{type: :else, condition: nil, path: nil, position: 10},
        %{type: :else, condition: nil, path: nil, position: 20},
        %{type: :endif, condition: nil, path: nil, position: 30}
      ]

      # Act
      result = Conditional.validate_pairs(conditionals)

      # Assert
      assert {:error, "Multiple @else@ markers in conditional block starting at position 0"} = result
    end

    test "validates multiple if/else/endif blocks" do
      # Arrange
      conditionals = [
        %{type: :if, condition: "first", path: ["first"], position: 0},
        %{type: :else, condition: nil, path: nil, position: 12},
        %{type: :endif, condition: nil, path: nil, position: 20},
        %{type: :if, condition: "second", path: ["second"], position: 30},
        %{type: :else, condition: nil, path: nil, position: 45},
        %{type: :endif, condition: nil, path: nil, position: 53}
      ]

      # Act
      result = Conditional.validate_pairs(conditionals)

      # Assert
      assert :ok = result
    end

    test "validates if/endif without else (backward compatibility)" do
      # Arrange
      conditionals = [
        %{type: :if, condition: "show", path: ["show"], position: 0},
        %{type: :endif, condition: nil, path: nil, position: 13}
      ]

      # Act
      result = Conditional.validate_pairs(conditionals)

      # Assert
      assert :ok = result
    end
  end

  describe "integration scenarios" do
    test "handles complex template with multiple sections" do
      # Arrange
      text = """
      Dear @if:customer.premium@Premium@endif@ Customer,

      @if:show_discount@
      Your discount code is: SAVE20
      @endif@

      Thank you!
      """

      # Act
      conditionals = Conditional.detect_conditionals(text)
      validation = Conditional.validate_pairs(conditionals)

      # Assert
      assert length(conditionals) == 4
      assert :ok = validation
    end

    test "detects validation error in complex template" do
      # Arrange
      text = """
      @if:section1@
      Content 1
      @endif@

      @if:section2@
      Content 2
      """

      # Act
      conditionals = Conditional.detect_conditionals(text)
      validation = Conditional.validate_pairs(conditionals)

      # Assert
      assert {:error, message} = validation
      assert message =~ "Unmatched @if:section2@"
    end

    test "handles template with no conditionals" do
      # Arrange
      text = "Simple template with no conditionals"

      # Act
      conditionals = Conditional.detect_conditionals(text)
      validation = Conditional.validate_pairs(conditionals)

      # Assert
      assert [] = conditionals
      assert :ok = validation
    end
  end

  describe "evaluate_condition/2" do
    test "returns true for truthy boolean value" do
      # Arrange
      data = %{"active" => true}
      path = ["active"]

      # Act
      result = Conditional.evaluate_condition(path, data)

      # Assert
      assert {:ok, true} = result
    end

    test "returns false for false boolean value" do
      # Arrange
      data = %{"active" => false}
      path = ["active"]

      # Act
      result = Conditional.evaluate_condition(path, data)

      # Assert
      assert {:ok, false} = result
    end

    test "returns false for zero integer" do
      # Arrange
      data = %{"count" => 0}
      path = ["count"]

      # Act
      result = Conditional.evaluate_condition(path, data)

      # Assert
      assert {:ok, false} = result
    end

    test "returns true for non-zero integer" do
      # Arrange
      data = %{"count" => 5}
      path = ["count"]

      # Act
      result = Conditional.evaluate_condition(path, data)

      # Assert
      assert {:ok, true} = result
    end

    test "returns false for zero float" do
      # Arrange
      data = %{"score" => 0.0}
      path = ["score"]

      # Act
      result = Conditional.evaluate_condition(path, data)

      # Assert
      assert {:ok, false} = result
    end

    test "returns true for non-zero float" do
      # Arrange
      data = %{"score" => 3.14}
      path = ["score"]

      # Act
      result = Conditional.evaluate_condition(path, data)

      # Assert
      assert {:ok, true} = result
    end

    test "returns false for empty string" do
      # Arrange
      data = %{"name" => ""}
      path = ["name"]

      # Act
      result = Conditional.evaluate_condition(path, data)

      # Assert
      assert {:ok, false} = result
    end

    test "returns true for non-empty string" do
      # Arrange
      data = %{"name" => "John"}
      path = ["name"]

      # Act
      result = Conditional.evaluate_condition(path, data)

      # Assert
      assert {:ok, true} = result
    end

    test "evaluates nested data path" do
      # Arrange
      data = %{"customer" => %{"active" => true}}
      path = ["customer", "active"]

      # Act
      result = Conditional.evaluate_condition(path, data)

      # Assert
      assert {:ok, true} = result
    end

    test "evaluates deeply nested data path" do
      # Arrange
      data = %{"user" => %{"profile" => %{"verified" => true}}}
      path = ["user", "profile", "verified"]

      # Act
      result = Conditional.evaluate_condition(path, data)

      # Assert
      assert {:ok, true} = result
    end

    test "uses case-insensitive matching" do
      # Arrange
      data = %{"name" => "John"}
      path = ["Name"]

      # Act
      result = Conditional.evaluate_condition(path, data)

      # Assert
      assert {:ok, true} = result
    end

    test "uses case-insensitive matching for nested paths" do
      # Arrange
      data = %{"customer" => %{"active" => true}}
      path = ["Customer", "Active"]

      # Act
      result = Conditional.evaluate_condition(path, data)

      # Assert
      assert {:ok, true} = result
    end

    test "returns error for missing path" do
      # Arrange
      data = %{"name" => "John"}
      path = ["missing"]

      # Act
      result = Conditional.evaluate_condition(path, data)

      # Assert
      assert {:error, {:path_not_found, ["missing"]}} = result
    end

    test "returns error for missing nested path" do
      # Arrange
      data = %{"customer" => %{"name" => "John"}}
      path = ["customer", "missing"]

      # Act
      result = Conditional.evaluate_condition(path, data)

      # Assert
      assert {:error, {:path_not_found, ["customer", "missing"]}} = result
    end

    test "handles nil value as falsy" do
      # Arrange
      data = %{"value" => nil}
      path = ["value"]

      # Act
      result = Conditional.evaluate_condition(path, data)

      # Assert
      assert {:ok, false} = result
    end
  end

  describe "find_section_boundaries/3" do
    import Ootempl.Xml

    test "finds boundaries in single paragraph section" do
      # Arrange
      xml_string = """
      <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:body>
          <w:p><w:r><w:t>@if:active@Content@endif@</w:t></w:r></w:p>
        </w:body>
      </w:document>
      """

      {:ok, doc} = Ootempl.Xml.parse(xml_string)

      # Act
      result = Conditional.find_section_boundaries(doc, "@if:active@", "@endif@")

      # Assert
      assert {:ok, {start_para, end_para}} = result
      assert start_para == end_para
    end

    test "finds boundaries spanning multiple paragraphs" do
      # Arrange
      xml_string = """
      <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:body>
          <w:p><w:r><w:t>@if:active@</w:t></w:r></w:p>
          <w:p><w:r><w:t>Content line 1</w:t></w:r></w:p>
          <w:p><w:r><w:t>Content line 2</w:t></w:r></w:p>
          <w:p><w:r><w:t>@endif@</w:t></w:r></w:p>
        </w:body>
      </w:document>
      """

      {:ok, doc} = Ootempl.Xml.parse(xml_string)

      # Act
      result = Conditional.find_section_boundaries(doc, "@if:active@", "@endif@")

      # Assert
      assert {:ok, {start_para, end_para}} = result
      assert start_para != end_para
    end

    test "returns error when if marker not found" do
      # Arrange
      xml_string = """
      <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:body>
          <w:p><w:r><w:t>Content</w:t></w:r></w:p>
          <w:p><w:r><w:t>@endif@</w:t></w:r></w:p>
        </w:body>
      </w:document>
      """

      {:ok, doc} = Ootempl.Xml.parse(xml_string)

      # Act
      result = Conditional.find_section_boundaries(doc, "@if:active@", "@endif@")

      # Assert
      assert {:error, :if_marker_not_found} = result
    end

    test "returns error when endif marker not found" do
      # Arrange
      xml_string = """
      <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:body>
          <w:p><w:r><w:t>@if:active@</w:t></w:r></w:p>
          <w:p><w:r><w:t>Content</w:t></w:r></w:p>
        </w:body>
      </w:document>
      """

      {:ok, doc} = Ootempl.Xml.parse(xml_string)

      # Act
      result = Conditional.find_section_boundaries(doc, "@if:active@", "@endif@")

      # Assert
      assert {:error, :endif_marker_not_found} = result
    end

    test "finds boundaries with nested elements" do
      # Arrange
      xml_string = """
      <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:body>
          <w:p><w:r><w:t>@if:active@</w:t></w:r></w:p>
          <w:tbl>
            <w:tr>
              <w:tc><w:p><w:r><w:t>Table cell</w:t></w:r></w:p></w:tc>
            </w:tr>
          </w:tbl>
          <w:p><w:r><w:t>@endif@</w:t></w:r></w:p>
        </w:body>
      </w:document>
      """

      {:ok, doc} = Ootempl.Xml.parse(xml_string)

      # Act
      result = Conditional.find_section_boundaries(doc, "@if:active@", "@endif@")

      # Assert
      assert {:ok, {_start_para, _end_para}} = result
    end
  end

  describe "collect_section_nodes/3" do
    import Ootempl.Xml

    test "collects nodes for single paragraph section" do
      # Arrange
      xml_string = """
      <w:body xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:p><w:r><w:t>@if:active@Content@endif@</w:t></w:r></w:p>
      </w:body>
      """

      {:ok, doc} = Ootempl.Xml.parse(xml_string)
      {:ok, {start_para, end_para}} = Conditional.find_section_boundaries(doc, "@if:active@", "@endif@")

      # Act
      result = Conditional.collect_section_nodes(doc, start_para, end_para)

      # Assert
      assert {:ok, nodes} = result
      assert length(nodes) == 1
    end

    test "collects nodes spanning multiple paragraphs" do
      # Arrange
      xml_string = """
      <w:body xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:p><w:r><w:t>Before</w:t></w:r></w:p>
        <w:p><w:r><w:t>@if:active@</w:t></w:r></w:p>
        <w:p><w:r><w:t>Content 1</w:t></w:r></w:p>
        <w:p><w:r><w:t>Content 2</w:t></w:r></w:p>
        <w:p><w:r><w:t>@endif@</w:t></w:r></w:p>
        <w:p><w:r><w:t>After</w:t></w:r></w:p>
      </w:body>
      """

      {:ok, doc} = Ootempl.Xml.parse(xml_string)
      {:ok, {start_para, end_para}} = Conditional.find_section_boundaries(doc, "@if:active@", "@endif@")

      # Act
      result = Conditional.collect_section_nodes(doc, start_para, end_para)

      # Assert
      assert {:ok, nodes} = result
      # Should include: start para, 2 content paras, end para = 4 paragraphs
      # But XML may include whitespace text nodes, so filter to count paragraphs
      paragraph_nodes =
        Enum.filter(nodes, fn node ->
          Record.is_record(node, :xmlElement) and xmlElement(node, :name) == :"w:p"
        end)

      assert length(paragraph_nodes) == 4
    end

    test "collects nodes including tables and other elements" do
      # Arrange
      xml_string = """
      <w:body xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:p><w:r><w:t>@if:active@</w:t></w:r></w:p>
        <w:tbl>
          <w:tr><w:tc><w:p><w:r><w:t>Cell</w:t></w:r></w:p></w:tc></w:tr>
        </w:tbl>
        <w:p><w:r><w:t>@endif@</w:t></w:r></w:p>
      </w:body>
      """

      {:ok, doc} = Ootempl.Xml.parse(xml_string)
      {:ok, {start_para, end_para}} = Conditional.find_section_boundaries(doc, "@if:active@", "@endif@")

      # Act
      result = Conditional.collect_section_nodes(doc, start_para, end_para)

      # Assert
      assert {:ok, nodes} = result
      # Should include: start para, table, end para = 3 element nodes
      # But XML may include whitespace text nodes, so filter to count elements
      element_nodes = Enum.filter(nodes, &Record.is_record(&1, :xmlElement))

      assert length(element_nodes) == 3
    end

    test "returns error when boundaries not found in element" do
      # Arrange
      xml_string = """
      <w:body xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:p><w:r><w:t>Content</w:t></w:r></w:p>
      </w:body>
      """

      {:ok, doc} = Ootempl.Xml.parse(xml_string)

      # Create fake paragraph nodes that don't exist in doc
      fake_start = xmlElement(name: :"w:p", content: [])
      fake_end = xmlElement(name: :"w:p", content: [])

      # Act
      result = Conditional.collect_section_nodes(doc, fake_start, fake_end)

      # Assert
      assert {:error, :boundaries_not_found} = result
    end
  end
end
