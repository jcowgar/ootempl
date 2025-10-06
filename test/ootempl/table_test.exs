defmodule Ootempl.TableTest do
  use ExUnit.Case, async: true

  import Ootempl.Xml

  alias Ootempl.Table

  @word_ns ~s(xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main")

  describe "find_tables/1" do
    test "finds single table in document" do
      # Arrange
      xml = """
      <w:document #{@word_ns}>
        <w:body>
          <w:tbl xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
            <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:tc><w:p><w:r><w:t>Cell</w:t></w:r></w:p></w:tc></w:tr>
          </w:tbl>
        </w:body>
      </w:document>
      """

      {:ok, doc} = Ootempl.Xml.parse(xml)

      # Act
      tables = Table.find_tables(doc)

      # Assert
      assert length(tables) == 1
      assert element_name(hd(tables)) == "w:tbl"
    end

    test "finds multiple tables in document" do
      # Arrange
      xml = """
      <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:body>
          <w:tbl xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
            <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:tc><w:p><w:r><w:t>Table 1</w:t></w:r></w:p></w:tc></w:tr>
          </w:tbl>
          <w:p><w:r><w:t>Text between tables</w:t></w:r></w:p>
          <w:tbl xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
            <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:tc><w:p><w:r><w:t>Table 2</w:t></w:r></w:p></w:tc></w:tr>
          </w:tbl>
        </w:body>
      </w:document>
      """

      {:ok, doc} = Ootempl.Xml.parse(xml)

      # Act
      tables = Table.find_tables(doc)

      # Assert
      assert length(tables) == 2
    end

    test "returns empty list when no tables present" do
      # Arrange
      xml = """
      <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:body>
          <w:p><w:r><w:t>Just text, no tables</w:t></w:r></w:p>
        </w:body>
      </w:document>
      """

      {:ok, doc} = Ootempl.Xml.parse(xml)

      # Act
      tables = Table.find_tables(doc)

      # Assert
      assert tables == []
    end

    test "finds nested tables" do
      # Arrange
      xml = """
      <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:body>
          <w:tbl xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
            <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
              <w:tc>
                <w:tbl xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
                  <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:tc><w:p><w:r><w:t>Nested</w:t></w:r></w:p></w:tc></w:tr>
                </w:tbl>
              </w:tc>
            </w:tr>
          </w:tbl>
        </w:body>
      </w:document>
      """

      {:ok, doc} = Ootempl.Xml.parse(xml)

      # Act
      tables = Table.find_tables(doc)

      # Assert
      assert length(tables) == 2
    end
  end

  describe "extract_rows/1" do
    test "extracts rows from table" do
      # Arrange
      xml = """
      <w:tbl xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:tc><w:p><w:r><w:t>Row 1</w:t></w:r></w:p></w:tc></w:tr>
        <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:tc><w:p><w:r><w:t>Row 2</w:t></w:r></w:p></w:tc></w:tr>
        <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:tc><w:p><w:r><w:t>Row 3</w:t></w:r></w:p></w:tc></w:tr>
      </w:tbl>
      """

      {:ok, table} = Ootempl.Xml.parse(xml)

      # Act
      rows = Table.extract_rows(table)

      # Assert
      assert length(rows) == 3
      assert Enum.all?(rows, fn row -> element_name(row) == "w:tr" end)
    end

    test "returns empty list for table with no rows" do
      # Arrange
      xml = """
      <w:tbl xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:tblPr></w:tblPr>
      </w:tbl>
      """

      {:ok, table} = Ootempl.Xml.parse(xml)

      # Act
      rows = Table.extract_rows(table)

      # Assert
      assert rows == []
    end

    test "extracts rows from table with complex structure" do
      # Arrange
      xml = """
      <w:tbl xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:tblPr>
          <w:tblStyle w:val="TableGrid"/>
        </w:tblPr>
        <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:tc><w:p><w:r><w:t>Cell 1</w:t></w:r></w:p></w:tc>
          <w:tc><w:p><w:r><w:t>Cell 2</w:t></w:r></w:p></w:tc>
        </w:tr>
        <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:tc><w:p><w:r><w:t>Cell 3</w:t></w:r></w:p></w:tc>
          <w:tc><w:p><w:r><w:t>Cell 4</w:t></w:r></w:p></w:tc>
        </w:tr>
      </w:tbl>
      """

      {:ok, table} = Ootempl.Xml.parse(xml)

      # Act
      rows = Table.extract_rows(table)

      # Assert
      assert length(rows) == 2
    end
  end

  describe "analyze_row/2" do
    test "identifies regular row without list reference" do
      # Arrange
      xml = """
      <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:tc><w:p><w:r><w:t>Hello @name@</w:t></w:r></w:p></w:tc>
      </w:tr>
      """

      {:ok, row} = Ootempl.Xml.parse(xml)
      data = %{"name" => "John"}

      # Act
      {:ok, analysis} = Table.analyze_row(row, data)

      # Assert
      assert analysis.template? == false
      assert analysis.list_key == nil
      assert length(analysis.placeholders) == 1
      assert hd(analysis.placeholders).variable == "name"
    end

    test "identifies template row with list reference" do
      # Arrange
      xml = """
      <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:tc><w:p><w:r><w:t>Claim: @claims.id@</w:t></w:r></w:p></w:tc>
      </w:tr>
      """

      {:ok, row} = Ootempl.Xml.parse(xml)
      data = %{"claims" => [%{"id" => 5565}, %{"id" => 5566}]}

      # Act
      {:ok, analysis} = Table.analyze_row(row, data)

      # Assert
      assert analysis.template? == true
      assert analysis.list_key == "claims"
      assert length(analysis.placeholders) == 1
    end

    test "handles row with no placeholders" do
      # Arrange
      xml = """
      <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:tc><w:p><w:r><w:t>Static text</w:t></w:r></w:p></w:tc>
      </w:tr>
      """

      {:ok, row} = Ootempl.Xml.parse(xml)
      data = %{}

      # Act
      {:ok, analysis} = Table.analyze_row(row, data)

      # Assert
      assert analysis.template? == false
      assert analysis.list_key == nil
      assert analysis.placeholders == []
    end

    test "handles row with multiple cells" do
      # Arrange
      xml = """
      <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:tc><w:p><w:r><w:t>ID: @claims.id@</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>Date: @claims.create_date@</w:t></w:r></w:p></w:tc>
      </w:tr>
      """

      {:ok, row} = Ootempl.Xml.parse(xml)
      data = %{"claims" => [%{"id" => 1, "create_date" => "2024-01-01"}]}

      # Act
      {:ok, analysis} = Table.analyze_row(row, data)

      # Assert
      assert analysis.template? == true
      assert analysis.list_key == "claims"
      assert length(analysis.placeholders) == 2
    end

    test "handles mixed references - list and non-list" do
      # Arrange
      xml = """
      <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:tc><w:p><w:r><w:t>@claims.id@ for @customer_name@</w:t></w:r></w:p></w:tc>
      </w:tr>
      """

      {:ok, row} = Ootempl.Xml.parse(xml)

      data = %{
        "claims" => [%{"id" => 1}],
        "customer_name" => "John"
      }

      # Act
      {:ok, analysis} = Table.analyze_row(row, data)

      # Assert
      assert analysis.template? == true
      assert analysis.list_key == "claims"
      assert length(analysis.placeholders) == 2
    end

    test "returns error when multiple different lists referenced" do
      # Arrange
      xml = """
      <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:tc><w:p><w:r><w:t>@claims.id@ | @orders.total@</w:t></w:r></w:p></w:tc>
      </w:tr>
      """

      {:ok, row} = Ootempl.Xml.parse(xml)

      data = %{
        "claims" => [%{"id" => 1}],
        "orders" => [%{"total" => 100}]
      }

      # Act
      result = Table.analyze_row(row, data)

      # Assert
      assert result == {:error, :multiple_lists}
    end

    test "handles nested list reference" do
      # Arrange
      xml = """
      <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:tc><w:p><w:r><w:t>@customer.orders.id@</w:t></w:r></w:p></w:tc>
      </w:tr>
      """

      {:ok, row} = Ootempl.Xml.parse(xml)

      data = %{
        "customer" => %{
          "orders" => [%{"id" => 1}, %{"id" => 2}]
        }
      }

      # Act
      {:ok, analysis} = Table.analyze_row(row, data)

      # Assert
      # Only the first path segment is checked for list reference
      assert analysis.template? == false
      assert analysis.list_key == nil
    end

    test "handles placeholder referencing non-existent data key" do
      # Arrange
      xml = """
      <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:tc><w:p><w:r><w:t>@unknown@</w:t></w:r></w:p></w:tc>
      </w:tr>
      """

      {:ok, row} = Ootempl.Xml.parse(xml)
      data = %{"name" => "John"}

      # Act
      {:ok, analysis} = Table.analyze_row(row, data)

      # Assert
      assert analysis.template? == false
      assert analysis.list_key == nil
    end

    test "handles empty list in data" do
      # Arrange
      xml = """
      <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:tc><w:p><w:r><w:t>@claims.id@</w:t></w:r></w:p></w:tc>
      </w:tr>
      """

      {:ok, row} = Ootempl.Xml.parse(xml)
      data = %{"claims" => []}

      # Act
      {:ok, analysis} = Table.analyze_row(row, data)

      # Assert
      assert analysis.template? == true
      assert analysis.list_key == "claims"
    end
  end

  describe "group_template_rows/2" do
    test "groups consecutive template rows referencing same list" do
      # Arrange
      xml = """
      <w:tbl xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:tc><w:p><w:r><w:t>Header</w:t></w:r></w:p></w:tc></w:tr>
        <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:tc><w:p><w:r><w:t>@claims.id@</w:t></w:r></w:p></w:tc></w:tr>
        <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:tc><w:p><w:r><w:t>@claims.date@</w:t></w:r></w:p></w:tc></w:tr>
        <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:tc><w:p><w:r><w:t>Footer</w:t></w:r></w:p></w:tc></w:tr>
      </w:tbl>
      """

      {:ok, table} = Ootempl.Xml.parse(xml)
      rows = Table.extract_rows(table)
      data = %{"claims" => [%{"id" => 1, "date" => "2024-01-01"}]}

      # Act
      {:ok, analyses} = Table.group_template_rows(rows, data)

      # Assert
      assert length(analyses) == 4
      assert Enum.at(analyses, 0).template? == false
      assert Enum.at(analyses, 1).template? == true
      assert Enum.at(analyses, 1).list_key == "claims"
      assert Enum.at(analyses, 2).template? == true
      assert Enum.at(analyses, 2).list_key == "claims"
      assert Enum.at(analyses, 3).template? == false
    end

    test "does not group non-consecutive template rows" do
      # Arrange
      xml = """
      <w:tbl xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:tc><w:p><w:r><w:t>@claims.id@</w:t></w:r></w:p></w:tc></w:tr>
        <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:tc><w:p><w:r><w:t>Separator</w:t></w:r></w:p></w:tc></w:tr>
        <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:tc><w:p><w:r><w:t>@claims.date@</w:t></w:r></w:p></w:tc></w:tr>
      </w:tbl>
      """

      {:ok, table} = Ootempl.Xml.parse(xml)
      rows = Table.extract_rows(table)
      data = %{"claims" => [%{"id" => 1, "date" => "2024-01-01"}]}

      # Act
      {:ok, analyses} = Table.group_template_rows(rows, data)

      # Assert
      assert length(analyses) == 3
      assert Enum.at(analyses, 0).template? == true
      assert Enum.at(analyses, 1).template? == false
      assert Enum.at(analyses, 2).template? == true
    end

    test "handles table with all regular rows" do
      # Arrange
      xml = """
      <w:tbl xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:tc><w:p><w:r><w:t>Row 1</w:t></w:r></w:p></w:tc></w:tr>
        <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:tc><w:p><w:r><w:t>Row 2</w:t></w:r></w:p></w:tc></w:tr>
      </w:tbl>
      """

      {:ok, table} = Ootempl.Xml.parse(xml)
      rows = Table.extract_rows(table)
      data = %{}

      # Act
      {:ok, analyses} = Table.group_template_rows(rows, data)

      # Assert
      assert length(analyses) == 2
      assert Enum.all?(analyses, fn a -> a.template? == false end)
    end

    test "handles table with all template rows" do
      # Arrange
      xml = """
      <w:tbl xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:tc><w:p><w:r><w:t>@claims.id@</w:t></w:r></w:p></w:tc></w:tr>
        <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:tc><w:p><w:r><w:t>@claims.date@</w:t></w:r></w:p></w:tc></w:tr>
        <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:tc><w:p><w:r><w:t>@claims.amount@</w:t></w:r></w:p></w:tc></w:tr>
      </w:tbl>
      """

      {:ok, table} = Ootempl.Xml.parse(xml)
      rows = Table.extract_rows(table)
      data = %{"claims" => [%{"id" => 1, "date" => "2024-01-01", "amount" => 100}]}

      # Act
      {:ok, analyses} = Table.group_template_rows(rows, data)

      # Assert
      assert length(analyses) == 3
      assert Enum.all?(analyses, fn a -> a.template? == true end)
      assert Enum.all?(analyses, fn a -> a.list_key == "claims" end)
    end

    test "returns error when row has multiple list references" do
      # Arrange
      xml = """
      <w:tbl xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:tc><w:p><w:r><w:t>@claims.id@ | @orders.total@</w:t></w:r></w:p></w:tc></w:tr>
      </w:tbl>
      """

      {:ok, table} = Ootempl.Xml.parse(xml)
      rows = Table.extract_rows(table)

      data = %{
        "claims" => [%{"id" => 1}],
        "orders" => [%{"total" => 100}]
      }

      # Act
      result = Table.group_template_rows(rows, data)

      # Assert
      assert match?({:error, {:multiple_lists, _}}, result)
    end

    test "handles empty table" do
      # Arrange
      xml = """
      <w:tbl xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:tblPr></w:tblPr>
      </w:tbl>
      """

      {:ok, table} = Ootempl.Xml.parse(xml)
      rows = Table.extract_rows(table)
      data = %{}

      # Act
      {:ok, analyses} = Table.group_template_rows(rows, data)

      # Assert
      assert analyses == []
    end

    test "distinguishes different list references" do
      # Arrange
      xml = """
      <w:tbl xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:tc><w:p><w:r><w:t>@claims.id@</w:t></w:r></w:p></w:tc></w:tr>
        <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:tc><w:p><w:r><w:t>@claims.date@</w:t></w:r></w:p></w:tc></w:tr>
        <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:tc><w:p><w:r><w:t>@orders.id@</w:t></w:r></w:p></w:tc></w:tr>
      </w:tbl>
      """

      {:ok, table} = Ootempl.Xml.parse(xml)
      rows = Table.extract_rows(table)

      data = %{
        "claims" => [%{"id" => 1, "date" => "2024-01-01"}],
        "orders" => [%{"id" => 2}]
      }

      # Act
      {:ok, analyses} = Table.group_template_rows(rows, data)

      # Assert
      assert length(analyses) == 3
      assert Enum.at(analyses, 0).list_key == "claims"
      assert Enum.at(analyses, 1).list_key == "claims"
      assert Enum.at(analyses, 2).list_key == "orders"
    end
  end

  describe "list_reference?/2" do
    test "returns true when key references a list" do
      # Arrange
      data = %{"claims" => [%{"id" => 1}]}

      # Act
      result = Table.list_reference?("claims", data)

      # Assert
      assert result == true
    end

    test "returns false when key references a string" do
      # Arrange
      data = %{"name" => "John"}

      # Act
      result = Table.list_reference?("name", data)

      # Assert
      assert result == false
    end

    test "returns false when key references a map" do
      # Arrange
      data = %{"customer" => %{"name" => "John"}}

      # Act
      result = Table.list_reference?("customer", data)

      # Assert
      assert result == false
    end

    test "returns false when key references a number" do
      # Arrange
      data = %{"count" => 42}

      # Act
      result = Table.list_reference?("count", data)

      # Assert
      assert result == false
    end

    test "returns false when key does not exist" do
      # Arrange
      data = %{"name" => "John"}

      # Act
      result = Table.list_reference?("unknown", data)

      # Assert
      assert result == false
    end

    test "returns true for empty list" do
      # Arrange
      data = %{"items" => []}

      # Act
      result = Table.list_reference?("items", data)

      # Assert
      assert result == true
    end

    test "returns false when key references nil" do
      # Arrange
      data = %{"value" => nil}

      # Act
      result = Table.list_reference?("value", data)

      # Assert
      assert result == false
    end
  end

  describe "scope_data/2" do
    test "merges list item with parent data" do
      # Arrange
      parent = %{"first_name" => "John", "company" => "Acme"}
      item = %{"id" => 5565, "amount" => 1000}

      # Act
      result = Table.scope_data(item, parent)

      # Assert
      assert result == %{
               "first_name" => "John",
               "company" => "Acme",
               "id" => 5565,
               "amount" => 1000
             }
    end

    test "list item overrides parent on key conflict" do
      # Arrange
      parent = %{"status" => "active", "name" => "John"}
      item = %{"status" => "pending", "amount" => 100}

      # Act
      result = Table.scope_data(item, parent)

      # Assert
      assert result["status"] == "pending"
      assert result["name"] == "John"
      assert result["amount"] == 100
    end

    test "handles empty parent data" do
      # Arrange
      parent = %{}
      item = %{"id" => 1, "value" => "test"}

      # Act
      result = Table.scope_data(item, parent)

      # Assert
      assert result == %{"id" => 1, "value" => "test"}
    end

    test "handles empty list item" do
      # Arrange
      parent = %{"name" => "John"}
      item = %{}

      # Act
      result = Table.scope_data(item, parent)

      # Assert
      assert result == %{"name" => "John"}
    end

    test "handles both empty" do
      # Arrange
      parent = %{}
      item = %{}

      # Act
      result = Table.scope_data(item, parent)

      # Assert
      assert result == %{}
    end
  end

  describe "clone_row/1" do
    test "clones simple row structure" do
      # Arrange
      xml = """
      <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:tc><w:p><w:r><w:t>Cell text</w:t></w:r></w:p></w:tc>
      </w:tr>
      """

      {:ok, row} = Ootempl.Xml.parse(xml)

      # Act
      cloned = Table.clone_row(row)

      # Assert
      assert element_name(cloned) == "w:tr"
      # Verify it has same structure by serializing
      {:ok, original_xml} = Ootempl.Xml.serialize(row)
      {:ok, cloned_xml} = Ootempl.Xml.serialize(cloned)
      assert original_xml == cloned_xml
    end

    test "clones row with multiple cells" do
      # Arrange
      xml = """
      <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:tc><w:p><w:r><w:t>Cell 1</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>Cell 2</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>Cell 3</w:t></w:r></w:p></w:tc>
      </w:tr>
      """

      {:ok, row} = Ootempl.Xml.parse(xml)

      # Act
      cloned = Table.clone_row(row)

      # Assert
      cells = Ootempl.Xml.find_elements(cloned, :"w:tc")
      assert length(cells) == 3
    end

    test "clones row with formatting attributes" do
      # Arrange
      xml = """
      <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:trPr>
          <w:trHeight w:val="360"/>
        </w:trPr>
        <w:tc>
          <w:tcPr>
            <w:shd w:fill="FF0000"/>
          </w:tcPr>
          <w:p><w:r><w:t>Red cell</w:t></w:r></w:p>
        </w:tc>
      </w:tr>
      """

      {:ok, row} = Ootempl.Xml.parse(xml)

      # Act
      cloned = Table.clone_row(row)

      # Assert
      # Verify formatting is preserved
      {:ok, cloned_xml} = Ootempl.Xml.serialize(cloned)
      assert String.contains?(cloned_xml, "w:trHeight")
      assert String.contains?(cloned_xml, "w:shd")
      assert String.contains?(cloned_xml, "FF0000")
    end

    test "preserves nested structure" do
      # Arrange
      xml = """
      <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:tc>
          <w:p>
            <w:pPr><w:jc w:val="center"/></w:pPr>
            <w:r>
              <w:rPr><w:b/><w:i/></w:rPr>
              <w:t>Bold Italic</w:t>
            </w:r>
          </w:p>
        </w:tc>
      </w:tr>
      """

      {:ok, row} = Ootempl.Xml.parse(xml)

      # Act
      cloned = Table.clone_row(row)

      # Assert
      {:ok, cloned_xml} = Ootempl.Xml.serialize(cloned)
      assert String.contains?(cloned_xml, "w:b")
      assert String.contains?(cloned_xml, "w:i")
      assert String.contains?(cloned_xml, "center")
    end
  end

  describe "duplicate_rows/3" do
    test "duplicates single row for each list item" do
      # Arrange
      xml = """
      <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:tc><w:p><w:r><w:t>@claims.id@</w:t></w:r></w:p></w:tc>
      </w:tr>
      """

      {:ok, template_row} = Ootempl.Xml.parse(xml)

      data = %{
        "first_name" => "John",
        "claims" => [%{"id" => 1}, %{"id" => 2}, %{"id" => 3}]
      }

      # Act
      result = Table.duplicate_rows([template_row], "claims", data)

      # Assert
      assert length(result) == 3

      # Verify each duplicated row has correct scoped data
      Enum.each(result, fn {row, scoped_data} ->
        assert element_name(row) == "w:tr"
        assert scoped_data["first_name"] == "John"
        assert is_integer(scoped_data["claims"]["id"])
        assert scoped_data["claims"]["id"] in [1, 2, 3]
      end)
    end

    test "duplicates multi-row template for each list item" do
      # Arrange
      xml1 = """
      <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:tc><w:p><w:r><w:t>ID: @claims.id@</w:t></w:r></w:p></w:tc>
      </w:tr>
      """

      xml2 = """
      <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:tc><w:p><w:r><w:t>Date: @claims.date@</w:t></w:r></w:p></w:tc>
      </w:tr>
      """

      {:ok, row1} = Ootempl.Xml.parse(xml1)
      {:ok, row2} = Ootempl.Xml.parse(xml2)

      data = %{
        "company" => "Acme",
        "claims" => [%{"id" => 100, "date" => "2024-01-01"}, %{"id" => 200, "date" => "2024-01-02"}]
      }

      # Act
      result = Table.duplicate_rows([row1, row2], "claims", data)

      # Assert
      # 2 template rows × 2 list items = 4 total rows
      assert length(result) == 4

      # First group (item 1)
      {_row1_dup1, data1} = Enum.at(result, 0)
      {_row2_dup1, data2} = Enum.at(result, 1)
      assert data1["company"] == "Acme"
      assert data1["claims"]["id"] == 100
      assert data1["claims"]["date"] == "2024-01-01"
      assert data2 == data1

      # Second group (item 2)
      {_row1_dup2, data3} = Enum.at(result, 2)
      {_row2_dup2, data4} = Enum.at(result, 3)
      assert data3["company"] == "Acme"
      assert data3["claims"]["id"] == 200
      assert data3["claims"]["date"] == "2024-01-02"
      assert data4 == data3
    end

    test "returns empty list for empty list data" do
      # Arrange
      xml = """
      <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:tc><w:p><w:r><w:t>@claims.id@</w:t></w:r></w:p></w:tc>
      </w:tr>
      """

      {:ok, template_row} = Ootempl.Xml.parse(xml)
      data = %{"claims" => []}

      # Act
      result = Table.duplicate_rows([template_row], "claims", data)

      # Assert
      assert result == []
    end

    test "handles non-list placeholders by duplicating to all rows" do
      # Arrange
      xml = """
      <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:tc><w:p><w:r><w:t>@claims.id@ - @company_name@</w:t></w:r></w:p></w:tc>
      </w:tr>
      """

      {:ok, template_row} = Ootempl.Xml.parse(xml)

      data = %{
        "company_name" => "Acme Corp",
        "claims" => [%{"id" => 1}, %{"id" => 2}]
      }

      # Act
      result = Table.duplicate_rows([template_row], "claims", data)

      # Assert
      assert length(result) == 2

      # Both rows should have company_name in scoped data
      Enum.each(result, fn {_row, scoped_data} ->
        assert scoped_data["company_name"] == "Acme Corp"
      end)
    end

    test "handles single item list" do
      # Arrange
      xml = """
      <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:tc><w:p><w:r><w:t>@items.value@</w:t></w:r></w:p></w:tc>
      </w:tr>
      """

      {:ok, template_row} = Ootempl.Xml.parse(xml)
      data = %{"items" => [%{"value" => "only one"}]}

      # Act
      result = Table.duplicate_rows([template_row], "items", data)

      # Assert
      assert length(result) == 1
      {_row, scoped_data} = hd(result)
      assert scoped_data["items"]["value"] == "only one"
    end

    test "handles large list (100+ items)" do
      # Arrange
      xml = """
      <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:tc><w:p><w:r><w:t>@items.index@</w:t></w:r></w:p></w:tc>
      </w:tr>
      """

      {:ok, template_row} = Ootempl.Xml.parse(xml)

      # Create 150 items
      items = Enum.map(1..150, fn i -> %{"index" => i} end)
      data = %{"items" => items}

      # Act
      result = Table.duplicate_rows([template_row], "items", data)

      # Assert
      assert length(result) == 150

      # Verify first and last items
      {_first_row, first_data} = hd(result)
      {_last_row, last_data} = List.last(result)
      assert first_data["items"]["index"] == 1
      assert last_data["items"]["index"] == 150
    end

    test "handles missing list key by treating as empty list" do
      # Arrange
      xml = """
      <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:tc><w:p><w:r><w:t>@unknown.field@</w:t></w:r></w:p></w:tc>
      </w:tr>
      """

      {:ok, template_row} = Ootempl.Xml.parse(xml)
      data = %{"other_field" => "value"}

      # Act
      result = Table.duplicate_rows([template_row], "unknown", data)

      # Assert
      assert result == []
    end
  end

  describe "insert_rows/3" do
    test "inserts rows at specified position" do
      # Arrange
      xml = """
      <w:tbl xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:tc><w:p><w:r><w:t>Row 1</w:t></w:r></w:p></w:tc></w:tr>
        <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:tc><w:p><w:r><w:t>Row 2</w:t></w:r></w:p></w:tc></w:tr>
        <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:tc><w:p><w:r><w:t>Row 3</w:t></w:r></w:p></w:tc></w:tr>
      </w:tbl>
      """

      {:ok, table} = Ootempl.Xml.parse(xml)

      new_row_xml = """
      <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:tc><w:p><w:r><w:t>Inserted</w:t></w:r></w:p></w:tc>
      </w:tr>
      """

      {:ok, new_row} = Ootempl.Xml.parse(new_row_xml)

      # Act - insert at position 1 (after first row)
      updated_table = Table.insert_rows(table, [new_row], 1)

      # Assert
      rows = Table.extract_rows(updated_table)
      assert length(rows) == 4
    end

    test "inserts multiple rows at position" do
      # Arrange
      xml = """
      <w:tbl xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:tc><w:p><w:r><w:t>Header</w:t></w:r></w:p></w:tc></w:tr>
        <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:tc><w:p><w:r><w:t>Footer</w:t></w:r></w:p></w:tc></w:tr>
      </w:tbl>
      """

      {:ok, table} = Ootempl.Xml.parse(xml)

      row1_xml = """
      <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:tc><w:p><w:r><w:t>Data 1</w:t></w:r></w:p></w:tc>
      </w:tr>
      """

      row2_xml = """
      <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:tc><w:p><w:r><w:t>Data 2</w:t></w:r></w:p></w:tc>
      </w:tr>
      """

      {:ok, row1} = Ootempl.Xml.parse(row1_xml)
      {:ok, row2} = Ootempl.Xml.parse(row2_xml)

      # Act - insert between header and footer
      updated_table = Table.insert_rows(table, [row1, row2], 1)

      # Assert
      rows = Table.extract_rows(updated_table)
      assert length(rows) == 4
    end

    test "inserts at position 0 (beginning)" do
      # Arrange
      xml = """
      <w:tbl xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:tc><w:p><w:r><w:t>Original</w:t></w:r></w:p></w:tc></w:tr>
      </w:tbl>
      """

      {:ok, table} = Ootempl.Xml.parse(xml)

      new_row_xml = """
      <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:tc><w:p><w:r><w:t>First</w:t></w:r></w:p></w:tc>
      </w:tr>
      """

      {:ok, new_row} = Ootempl.Xml.parse(new_row_xml)

      # Act
      updated_table = Table.insert_rows(table, [new_row], 0)

      # Assert
      rows = Table.extract_rows(updated_table)
      assert length(rows) == 2
    end

    test "handles empty row list" do
      # Arrange
      xml = """
      <w:tbl xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:tc><w:p><w:r><w:t>Row</w:t></w:r></w:p></w:tc></w:tr>
      </w:tbl>
      """

      {:ok, table} = Ootempl.Xml.parse(xml)

      # Act
      updated_table = Table.insert_rows(table, [], 0)

      # Assert
      rows = Table.extract_rows(updated_table)
      assert length(rows) == 1
    end

    test "returns unchanged table for out of bounds position" do
      # Arrange
      xml = """
      <w:tbl xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:tc><w:p><w:r><w:t>Row</w:t></w:r></w:p></w:tc></w:tr>
      </w:tbl>
      """

      {:ok, table} = Ootempl.Xml.parse(xml)

      new_row_xml = """
      <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:tc><w:p><w:r><w:t>New</w:t></w:r></w:p></w:tc>
      </w:tr>
      """

      {:ok, new_row} = Ootempl.Xml.parse(new_row_xml)

      # Act - position 10 is out of bounds
      updated_table = Table.insert_rows(table, [new_row], 10)

      # Assert
      rows = Table.extract_rows(updated_table)
      assert length(rows) == 1
    end
  end

  describe "remove_template_rows/2" do
    test "removes specified template rows from table" do
      # Arrange
      xml = """
      <w:tbl xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:tc><w:p><w:r><w:t>Keep</w:t></w:r></w:p></w:tc></w:tr>
        <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:tc><w:p><w:r><w:t>Remove</w:t></w:r></w:p></w:tc></w:tr>
        <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:tc><w:p><w:r><w:t>Keep</w:t></w:r></w:p></w:tc></w:tr>
      </w:tbl>
      """

      {:ok, table} = Ootempl.Xml.parse(xml)
      rows = Table.extract_rows(table)
      template_row = Enum.at(rows, 1)

      # Act
      updated_table = Table.remove_template_rows(table, [template_row])

      # Assert
      remaining_rows = Table.extract_rows(updated_table)
      assert length(remaining_rows) == 2
    end

    test "removes multiple template rows" do
      # Arrange
      xml = """
      <w:tbl xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:tc><w:p><w:r><w:t>Keep</w:t></w:r></w:p></w:tc></w:tr>
        <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:tc><w:p><w:r><w:t>Remove 1</w:t></w:r></w:p></w:tc></w:tr>
        <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:tc><w:p><w:r><w:t>Remove 2</w:t></w:r></w:p></w:tc></w:tr>
        <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:tc><w:p><w:r><w:t>Keep</w:t></w:r></w:p></w:tc></w:tr>
      </w:tbl>
      """

      {:ok, table} = Ootempl.Xml.parse(xml)
      rows = Table.extract_rows(table)
      template_rows = [Enum.at(rows, 1), Enum.at(rows, 2)]

      # Act
      updated_table = Table.remove_template_rows(table, template_rows)

      # Assert
      remaining_rows = Table.extract_rows(updated_table)
      assert length(remaining_rows) == 2
    end

    test "handles empty template row list" do
      # Arrange
      xml = """
      <w:tbl xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:tc><w:p><w:r><w:t>Row</w:t></w:r></w:p></w:tc></w:tr>
      </w:tbl>
      """

      {:ok, table} = Ootempl.Xml.parse(xml)

      # Act
      updated_table = Table.remove_template_rows(table, [])

      # Assert
      rows = Table.extract_rows(updated_table)
      assert length(rows) == 1
    end

    test "returns unchanged table if template row not found" do
      # Arrange
      xml = """
      <w:tbl xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:tc><w:p><w:r><w:t>Row</w:t></w:r></w:p></w:tc></w:tr>
      </w:tbl>
      """

      {:ok, table} = Ootempl.Xml.parse(xml)

      # Create a different row that's not in the table
      other_row_xml = """
      <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:tc><w:p><w:r><w:t>Other</w:t></w:r></w:p></w:tc>
      </w:tr>
      """

      {:ok, other_row} = Ootempl.Xml.parse(other_row_xml)

      # Act
      updated_table = Table.remove_template_rows(table, [other_row])

      # Assert
      rows = Table.extract_rows(updated_table)
      assert length(rows) == 1
    end

    test "can remove all rows from table" do
      # Arrange
      xml = """
      <w:tbl xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:tc><w:p><w:r><w:t>Row 1</w:t></w:r></w:p></w:tc></w:tr>
        <w:tr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:tc><w:p><w:r><w:t>Row 2</w:t></w:r></w:p></w:tc></w:tr>
      </w:tbl>
      """

      {:ok, table} = Ootempl.Xml.parse(xml)
      all_rows = Table.extract_rows(table)

      # Act
      updated_table = Table.remove_template_rows(table, all_rows)

      # Assert
      remaining_rows = Table.extract_rows(updated_table)
      assert remaining_rows == []
    end
  end
end
