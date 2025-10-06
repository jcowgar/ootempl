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
end
