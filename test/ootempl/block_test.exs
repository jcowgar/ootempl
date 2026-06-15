defmodule Ootempl.BlockTest do
  use ExUnit.Case, async: true

  import Ootempl.Xml

  alias Ootempl.Block

  require Record

  describe "detect_markers/1" do
    test "detects single open marker" do
      text = "{{#items}}"

      result = Block.detect_markers(text)

      assert [%{type: :open, list_key: "items", position: 0}] = result
    end

    test "detects single close marker" do
      text = "{{/items}}"

      result = Block.detect_markers(text)

      assert [%{type: :close, list_key: "items", position: 0}] = result
    end

    test "detects multiple markers in order" do
      text = "{{#outer}}{{#inner}}content{{/inner}}{{/outer}}"

      result = Block.detect_markers(text)

      assert [
               %{type: :open, list_key: "outer", position: 0},
               %{type: :open, list_key: "inner", position: 10},
               %{type: :close, list_key: "inner", position: 27},
               %{type: :close, list_key: "outer", position: 37}
             ] = result
    end

    test "handles escaped markers" do
      text = "\\{{#items}}"

      result = Block.detect_markers(text)

      assert [] = result
    end

    test "returns empty list for no markers" do
      text = "plain text with {{placeholder}}"

      result = Block.detect_markers(text)

      assert [] = result
    end

    test "handles empty text" do
      result = Block.detect_markers("")

      assert [] = result
    end

    test "handles variables starting with underscore" do
      text = "{{#_private}}"

      result = Block.detect_markers(text)

      assert [%{type: :open, list_key: "_private"}] = result
    end

    test "handles variables with numbers" do
      text = "{{#items123}}"

      result = Block.detect_markers(text)

      assert [%{type: :open, list_key: "items123"}] = result
    end

    test "detects markers with surrounding text" do
      text = "Before {{#items}} middle {{/items}} after"

      result = Block.detect_markers(text)

      assert [
               %{type: :open, list_key: "items", position: 7},
               %{type: :close, list_key: "items", position: 25}
             ] = result
    end
  end

  describe "contains_markers?/1" do
    test "returns true for open marker" do
      assert Block.contains_markers?("{{#items}}")
    end

    test "returns true for close marker" do
      assert Block.contains_markers?("{{/items}}")
    end

    test "returns true when markers are mixed with other content" do
      assert Block.contains_markers?("Some text {{#list}} more text")
    end

    test "returns false for regular placeholders" do
      refute Block.contains_markers?("{{name}}")
    end

    test "returns false for conditional markers" do
      refute Block.contains_markers?("{{if active}}{{endif}}")
    end

    test "returns false for plain text" do
      refute Block.contains_markers?("plain text")
    end

    test "returns false for empty string" do
      refute Block.contains_markers?("")
    end
  end

  describe "validate_pairs/1" do
    test "returns :ok for properly paired markers" do
      markers = [
        %{type: :open, list_key: "items", position: 0},
        %{type: :close, list_key: "items", position: 10}
      ]

      assert :ok = Block.validate_pairs(markers)
    end

    test "returns :ok for empty list" do
      assert :ok = Block.validate_pairs([])
    end

    test "returns error for unmatched open marker" do
      markers = [
        %{type: :open, list_key: "items", position: 5}
      ]

      assert {:error, "Unmatched {{#items}} at position 5"} = Block.validate_pairs(markers)
    end

    test "returns error for unmatched close marker" do
      markers = [
        %{type: :close, list_key: "items", position: 10}
      ]

      assert {:error, "Orphan {{/items}} at position 10 (no matching {{#items}})"} =
               Block.validate_pairs(markers)
    end

    test "validates nested blocks correctly" do
      markers = [
        %{type: :open, list_key: "outer", position: 0},
        %{type: :open, list_key: "inner", position: 10},
        %{type: :close, list_key: "inner", position: 20},
        %{type: :close, list_key: "outer", position: 30}
      ]

      assert :ok = Block.validate_pairs(markers)
    end

    test "returns error for overlapping blocks" do
      markers = [
        %{type: :open, list_key: "first", position: 0},
        %{type: :open, list_key: "second", position: 10},
        %{type: :close, list_key: "first", position: 20},
        %{type: :close, list_key: "second", position: 30}
      ]

      assert {:error, "Mismatched block: found {{/first}} at position 20, expected {{/second}}"} =
               Block.validate_pairs(markers)
    end

    test "returns error for mismatched marker keys" do
      markers = [
        %{type: :open, list_key: "items", position: 0},
        %{type: :close, list_key: "other", position: 10}
      ]

      assert {:error, "Mismatched block: found {{/other}} at position 10, expected {{/items}}"} =
               Block.validate_pairs(markers)
    end

    test "validates multiple sequential blocks" do
      markers = [
        %{type: :open, list_key: "first", position: 0},
        %{type: :close, list_key: "first", position: 10},
        %{type: :open, list_key: "second", position: 20},
        %{type: :close, list_key: "second", position: 30}
      ]

      assert :ok = Block.validate_pairs(markers)
    end
  end

  describe "parse_table_structure/2" do
    test "parses single-level block" do
      # Build simple table XML with block markers
      rows =
        build_test_rows([
          "{{#items}}",
          "{{name}} - {{price}}",
          "{{/items}}"
        ])

      data = %{"items" => [%{"name" => "A", "price" => 10}]}

      assert {:ok, structure} = Block.parse_table_structure(rows, data)
      assert structure.list_key == "items"
      assert structure.open_row_index == 0
      assert structure.close_row_index == 2
      assert structure.header_rows == [1]
      assert structure.body_block == nil
      assert structure.footer_rows == []
    end

    test "parses nested block with header/body/footer" do
      rows =
        build_test_rows([
          "{{#categories}}",
          "{{name}} - {{total}}",
          "{{#items}}",
          "{{item_name}} - {{price}}",
          "{{/items}}",
          "Subtotal: {{subtotal}}",
          "{{/categories}}"
        ])

      data = %{
        "categories" => [
          %{
            "name" => "Cat1",
            "total" => 100,
            "subtotal" => 100,
            "items" => [%{"item_name" => "A", "price" => 100}]
          }
        ]
      }

      assert {:ok, structure} = Block.parse_table_structure(rows, data)
      assert structure.list_key == "categories"
      assert structure.open_row_index == 0
      assert structure.close_row_index == 6
      assert structure.header_rows == [1]
      assert structure.footer_rows == [5]
      assert structure.body_block
      assert structure.body_block.list_key == "items"
      assert structure.body_block.header_rows == [3]
    end

    test "identifies marker-only rows" do
      rows =
        build_test_rows([
          "{{#items}}",
          "{{name}}",
          "{{/items}}"
        ])

      data = %{"items" => [%{"name" => "Test"}]}

      assert {:ok, structure} = Block.parse_table_structure(rows, data)

      marker_indices = Block.marker_row_indices(structure)
      assert marker_indices == [0, 2]
    end

    test "returns error for no block markers" do
      rows =
        build_test_rows([
          "{{name}}",
          "{{price}}"
        ])

      data = %{"name" => "Test", "price" => 10}

      assert {:error, :no_block_markers} = Block.parse_table_structure(rows, data)
    end
  end

  describe "expand_block/3" do
    test "expands single-level block" do
      rows =
        build_test_rows([
          "{{#items}}",
          "{{name}}",
          "{{/items}}"
        ])

      data = %{
        "items" => [
          %{"name" => "Item 1"},
          %{"name" => "Item 2"}
        ]
      }

      {:ok, structure} = Block.parse_table_structure(rows, data)
      result = Block.expand_block(structure, rows, data)

      # Should have 2 rows (1 per item), marker rows excluded
      assert length(result) == 2

      # Each result is a {row, scoped_data} tuple
      [{_row1, data1}, {_row2, data2}] = result
      assert data1["name"] == "Item 1"
      assert data2["name"] == "Item 2"
    end

    test "expands nested block with correct scoping" do
      rows =
        build_test_rows([
          "{{#categories}}",
          "{{category_name}}",
          "{{#items}}",
          "{{item_name}}",
          "{{/items}}",
          "{{subtotal}}",
          "{{/categories}}"
        ])

      data = %{
        "categories" => [
          %{
            "category_name" => "Electronics",
            "subtotal" => 300,
            "items" => [
              %{"item_name" => "Phone"},
              %{"item_name" => "Laptop"}
            ]
          }
        ]
      }

      {:ok, structure} = Block.parse_table_structure(rows, data)
      result = Block.expand_block(structure, rows, data)

      # Should have: 1 header + 2 body + 1 footer = 4 rows
      assert length(result) == 4

      # Check data scoping
      [{_h, hdata}, {_b1, b1data}, {_b2, b2data}, {_f, fdata}] = result

      # Header should have parent data
      assert hdata["category_name"] == "Electronics"

      # Body rows should have parent + child data
      assert b1data["category_name"] == "Electronics"
      assert b1data["item_name"] == "Phone"
      assert b2data["item_name"] == "Laptop"

      # Footer should have parent data
      assert fdata["subtotal"] == 300
    end

    test "returns empty for empty list" do
      rows =
        build_test_rows([
          "{{#items}}",
          "{{name}}",
          "{{/items}}"
        ])

      data = %{"items" => []}

      {:ok, structure} = Block.parse_table_structure(rows, data)
      result = Block.expand_block(structure, rows, data)

      assert result == []
    end

    test "handles empty children list" do
      rows =
        build_test_rows([
          "{{#categories}}",
          "{{name}}",
          "{{#items}}",
          "{{item}}",
          "{{/items}}",
          "{{/categories}}"
        ])

      data = %{
        "categories" => [
          %{"name" => "Empty Category", "items" => []}
        ]
      }

      {:ok, structure} = Block.parse_table_structure(rows, data)
      result = Block.expand_block(structure, rows, data)

      # Should have just the header row (no body rows since items is empty)
      assert length(result) == 1
      [{_row, row_data}] = result
      assert row_data["name"] == "Empty Category"
    end

    test "parent data accessible in child scope" do
      rows =
        build_test_rows([
          "{{#orders}}",
          "{{order_id}}",
          "{{#items}}",
          "{{order_id}} - {{item_name}}",
          "{{/items}}",
          "{{/orders}}"
        ])

      data = %{
        "orders" => [
          %{
            "order_id" => "ORD-001",
            "items" => [
              %{"item_name" => "Widget"}
            ]
          }
        ]
      }

      {:ok, structure} = Block.parse_table_structure(rows, data)
      result = Block.expand_block(structure, rows, data)

      # Body row should have access to parent's order_id
      [{_header, _}, {_body, body_data}] = result
      assert body_data["order_id"] == "ORD-001"
      assert body_data["item_name"] == "Widget"
    end
  end

  describe "marker_row_indices/1" do
    test "returns indices for single-level block" do
      rows =
        build_test_rows([
          "{{#items}}",
          "{{name}}",
          "{{/items}}"
        ])

      data = %{"items" => []}

      {:ok, structure} = Block.parse_table_structure(rows, data)
      indices = Block.marker_row_indices(structure)

      assert indices == [0, 2]
    end

    test "returns indices for nested block" do
      rows =
        build_test_rows([
          "{{#outer}}",
          "content",
          "{{#inner}}",
          "nested",
          "{{/inner}}",
          "{{/outer}}"
        ])

      data = %{"outer" => [%{"inner" => []}]}

      {:ok, structure} = Block.parse_table_structure(rows, data)
      indices = Block.marker_row_indices(structure)

      assert indices == [0, 2, 4, 5]
    end
  end

  describe "edge cases and additional coverage" do
    test "handles deeply nested blocks (3 levels)" do
      rows =
        build_test_rows([
          "{{#level1}}",
          "{{l1_name}}",
          "{{#level2}}",
          "{{l2_name}}",
          "{{#level3}}",
          "{{l3_name}}",
          "{{/level3}}",
          "{{/level2}}",
          "{{/level1}}"
        ])

      data = %{
        "level1" => [
          %{
            "l1_name" => "A",
            "level2" => [
              %{
                "l2_name" => "B",
                "level3" => [
                  %{"l3_name" => "C"}
                ]
              }
            ]
          }
        ]
      }

      {:ok, structure} = Block.parse_table_structure(rows, data)
      result = Block.expand_block(structure, rows, data)

      # Should have rows for all levels
      assert length(result) >= 1
    end

    test "handles block with only marker rows and no content rows" do
      rows =
        build_test_rows([
          "{{#items}}",
          "{{/items}}"
        ])

      data = %{"items" => [%{"name" => "test"}]}

      {:ok, structure} = Block.parse_table_structure(rows, data)

      # No content rows to expand
      assert structure.header_rows == []
      assert structure.footer_rows == []
    end

    test "handles missing children key in data" do
      rows =
        build_test_rows([
          "{{#categories}}",
          "{{name}}",
          "{{#items}}",
          "{{item}}",
          "{{/items}}",
          "{{/categories}}"
        ])

      data = %{
        "categories" => [
          %{"name" => "Category 1"}
          # Missing "items" key
        ]
      }

      {:ok, structure} = Block.parse_table_structure(rows, data)
      result = Block.expand_block(structure, rows, data)

      # Should still produce the header row
      assert length(result) == 1
    end

    test "handles non-list value at list key" do
      rows =
        build_test_rows([
          "{{#items}}",
          "{{name}}",
          "{{/items}}"
        ])

      data = %{
        "items" => "not a list"
      }

      {:ok, structure} = Block.parse_table_structure(rows, data)
      result = Block.expand_block(structure, rows, data)

      # Should return empty since items is not a list
      assert result == []
    end

    test "handles consecutive markers without content between them" do
      text = "{{#a}}{{#b}}{{/b}}{{/a}}"

      markers = Block.detect_markers(text)

      assert length(markers) == 4
      assert :ok = Block.validate_pairs(markers)
    end

    test "marker_row_indices returns empty for no markers" do
      rows =
        build_test_rows([
          "regular row"
        ])

      data = %{}

      # No markers, so parse should fail
      assert {:error, :no_block_markers} = Block.parse_table_structure(rows, data)
    end

    test "handles non-map child data gracefully" do
      rows =
        build_test_rows([
          "{{#items}}",
          "{{name}}",
          "{{/items}}"
        ])

      # Items contains non-map values
      data = %{
        "items" => ["string1", "string2"]
      }

      {:ok, structure} = Block.parse_table_structure(rows, data)
      result = Block.expand_block(structure, rows, data)

      # Should produce rows but with parent scope only (no merge with non-map)
      assert length(result) == 2
    end
  end

  # Helper function to build test table rows
  defp build_test_rows(texts) do
    Enum.map(texts, fn text ->
      text_node = xmlText(value: String.to_charlist(text))

      t_element =
        xmlElement(
          name: :"w:t",
          content: [text_node],
          attributes: []
        )

      r_element =
        xmlElement(
          name: :"w:r",
          content: [t_element],
          attributes: []
        )

      p_element =
        xmlElement(
          name: :"w:p",
          content: [r_element],
          attributes: []
        )

      tc_element =
        xmlElement(
          name: :"w:tc",
          content: [p_element],
          attributes: []
        )

      xmlElement(
        name: :"w:tr",
        content: [tc_element],
        attributes: []
      )
    end)
  end
end
