defmodule Ootempl.RelationshipsTest do
  use ExUnit.Case, async: true

  import Ootempl.Xml

  alias Ootempl.Relationships
  alias Ootempl.Xml

  require Record

  describe "parse_relationships/1" do
    test "parses valid relationship XML" do
      # Arrange
      xml = """
      <?xml version="1.0"?>
      <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
      </Relationships>
      """

      # Act
      result = Relationships.parse_relationships(xml)

      # Assert
      assert {:ok, element} = result
      assert Record.is_record(element, :xmlElement)
      assert xmlElement(element, :name) == :Relationships
    end

    test "parses empty relationships XML" do
      # Arrange
      xml = """
      <?xml version="1.0"?>
      <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      </Relationships>
      """

      # Act
      {:ok, element} = Relationships.parse_relationships(xml)

      # Assert
      assert Record.is_record(element, :xmlElement)
      content = xmlElement(element, :content)
      # Content may have whitespace text nodes but no Relationship elements
      relationship_elements =
        Enum.filter(content, fn node ->
          Record.is_record(node, :xmlElement) && xmlElement(node, :name) == :Relationship
        end)

      assert relationship_elements == []
    end

    test "parses relationships with multiple entries" do
      # Arrange
      xml = """
      <?xml version="1.0"?>
      <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://example.com/type1" Target="file1.xml"/>
        <Relationship Id="rId2" Type="http://example.com/type2" Target="file2.xml"/>
        <Relationship Id="rId5" Type="http://example.com/type3" Target="media/image1.png"/>
      </Relationships>
      """

      # Act
      {:ok, element} = Relationships.parse_relationships(xml)

      # Assert
      content = xmlElement(element, :content)

      relationship_elements =
        Enum.filter(content, fn node ->
          Record.is_record(node, :xmlElement) && xmlElement(node, :name) == :Relationship
        end)

      assert length(relationship_elements) == 3
    end

    test "returns error for malformed XML" do
      # Arrange
      xml = "<Relationships><Relationship"

      # Act
      result = Relationships.parse_relationships(xml)

      # Assert
      assert {:error, _reason} = result
    end

    test "returns error for empty string" do
      # Arrange
      xml = ""

      # Act
      result = Relationships.parse_relationships(xml)

      # Assert
      assert {:error, _reason} = result
    end
  end

  describe "extract_relationship_ids/1" do
    test "extracts single relationship ID" do
      # Arrange
      xml = """
      <?xml version="1.0"?>
      <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://example.com" Target="foo.xml"/>
      </Relationships>
      """

      {:ok, rels} = Relationships.parse_relationships(xml)

      # Act
      ids = Relationships.extract_relationship_ids(rels)

      # Assert
      assert ids == ["rId1"]
    end

    test "extracts multiple relationship IDs" do
      # Arrange
      xml = """
      <?xml version="1.0"?>
      <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://example.com" Target="foo.xml"/>
        <Relationship Id="rId5" Type="http://example.com" Target="bar.xml"/>
        <Relationship Id="rId10" Type="http://example.com" Target="baz.xml"/>
      </Relationships>
      """

      {:ok, rels} = Relationships.parse_relationships(xml)

      # Act
      ids = Relationships.extract_relationship_ids(rels)

      # Assert
      assert ids == ["rId1", "rId5", "rId10"]
    end

    test "returns empty list for relationships with no entries" do
      # Arrange
      xml = """
      <?xml version="1.0"?>
      <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      </Relationships>
      """

      {:ok, rels} = Relationships.parse_relationships(xml)

      # Act
      ids = Relationships.extract_relationship_ids(rels)

      # Assert
      assert ids == []
    end

    test "handles relationships with non-sequential IDs" do
      # Arrange
      xml = """
      <?xml version="1.0"?>
      <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId2" Type="http://example.com" Target="foo.xml"/>
        <Relationship Id="rId100" Type="http://example.com" Target="bar.xml"/>
        <Relationship Id="rId7" Type="http://example.com" Target="baz.xml"/>
      </Relationships>
      """

      {:ok, rels} = Relationships.parse_relationships(xml)

      # Act
      ids = Relationships.extract_relationship_ids(rels)

      # Assert
      assert ids == ["rId2", "rId100", "rId7"]
    end

    test "ignores elements without Id attribute" do
      # Arrange
      # Manually construct XML element with a Relationship missing Id attribute
      rel_without_id =
        xmlElement(
          name: :Relationship,
          attributes: [
            xmlAttribute(name: :Type, value: ~c"http://example.com"),
            xmlAttribute(name: :Target, value: ~c"foo.xml")
          ],
          content: []
        )

      rel_with_id =
        xmlElement(
          name: :Relationship,
          attributes: [
            xmlAttribute(name: :Id, value: ~c"rId5"),
            xmlAttribute(name: :Type, value: ~c"http://example.com"),
            xmlAttribute(name: :Target, value: ~c"bar.xml")
          ],
          content: []
        )

      rels_xml =
        xmlElement(
          name: :Relationships,
          content: [rel_without_id, rel_with_id],
          attributes: []
        )

      # Act
      ids = Relationships.extract_relationship_ids(rels_xml)

      # Assert
      assert ids == ["rId5"]
    end
  end

  describe "generate_unique_id/1" do
    test "generates rId1 for empty list" do
      # Arrange
      existing_ids = []

      # Act
      result = Relationships.generate_unique_id(existing_ids)

      # Assert
      assert result == "rId1"
    end

    test "generates next sequential ID" do
      # Arrange
      existing_ids = ["rId1", "rId2", "rId3"]

      # Act
      result = Relationships.generate_unique_id(existing_ids)

      # Assert
      assert result == "rId4"
    end

    test "generates ID after highest non-sequential ID" do
      # Arrange
      existing_ids = ["rId1", "rId5", "rId20"]

      # Act
      result = Relationships.generate_unique_id(existing_ids)

      # Assert
      assert result == "rId21"
    end

    test "handles single existing ID" do
      # Arrange
      existing_ids = ["rId10"]

      # Act
      result = Relationships.generate_unique_id(existing_ids)

      # Assert
      assert result == "rId11"
    end

    test "handles gaps in ID sequence" do
      # Arrange
      existing_ids = ["rId1", "rId3", "rId7"]

      # Act
      result = Relationships.generate_unique_id(existing_ids)

      # Assert
      assert result == "rId8"
    end

    test "avoids collision if generated ID already exists" do
      # Arrange
      # This tests the collision detection logic
      # Even though max is 5, if "rId6" exists, it should generate "rId7"
      existing_ids = ["rId5", "rId6"]

      # Act
      result = Relationships.generate_unique_id(existing_ids)

      # Assert
      assert result == "rId7"
    end

    test "handles large ID numbers" do
      # Arrange
      existing_ids = ["rId999", "rId1000"]

      # Act
      result = Relationships.generate_unique_id(existing_ids)

      # Assert
      assert result == "rId1001"
    end

    test "handles invalid ID formats gracefully" do
      # Arrange
      # Invalid formats should be treated as 0
      existing_ids = ["rId5", "invalid", "rId", "abc123"]

      # Act
      result = Relationships.generate_unique_id(existing_ids)

      # Assert
      # Should use the max valid number (5) and increment
      assert result == "rId6"
    end
  end

  describe "create_image_relationship/2" do
    test "creates relationship with correct structure" do
      # Arrange
      id = "rId10"
      target = "media/image1.png"

      # Act
      rel = Relationships.create_image_relationship(id, target)

      # Assert
      assert rel.id == "rId10"
      assert rel.target == "media/image1.png"
      assert rel.type == "http://schemas.openxmlformats.org/officeDocument/2006/relationships/image"
    end

    test "creates relationship with different ID" do
      # Arrange
      id = "rId100"
      target = "media/logo.jpeg"

      # Act
      rel = Relationships.create_image_relationship(id, target)

      # Assert
      assert rel.id == "rId100"
      assert rel.target == "media/logo.jpeg"
    end

    test "handles various target paths" do
      # Arrange & Act
      rel1 = Relationships.create_image_relationship("rId1", "media/image1.png")
      rel2 = Relationships.create_image_relationship("rId2", "images/photo.jpg")
      rel3 = Relationships.create_image_relationship("rId3", "assets/deep/nested/icon.gif")

      # Assert
      assert rel1.target == "media/image1.png"
      assert rel2.target == "images/photo.jpg"
      assert rel3.target == "assets/deep/nested/icon.gif"
    end
  end

  describe "add_relationship/2" do
    test "adds relationship to empty relationships XML" do
      # Arrange
      xml = """
      <?xml version="1.0"?>
      <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      </Relationships>
      """

      {:ok, rels} = Relationships.parse_relationships(xml)
      rel = Relationships.create_image_relationship("rId1", "media/image1.png")

      # Act
      updated = Relationships.add_relationship(rels, rel)

      # Assert
      ids = Relationships.extract_relationship_ids(updated)
      assert ids == ["rId1"]
    end

    test "adds relationship to existing relationships" do
      # Arrange
      xml = """
      <?xml version="1.0"?>
      <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://example.com" Target="styles.xml"/>
      </Relationships>
      """

      {:ok, rels} = Relationships.parse_relationships(xml)
      rel = Relationships.create_image_relationship("rId2", "media/image1.png")

      # Act
      updated = Relationships.add_relationship(rels, rel)

      # Assert
      ids = Relationships.extract_relationship_ids(updated)
      assert "rId1" in ids
      assert "rId2" in ids
      assert length(ids) == 2
    end

    test "adds multiple relationships sequentially" do
      # Arrange
      xml = """
      <?xml version="1.0"?>
      <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      </Relationships>
      """

      {:ok, rels} = Relationships.parse_relationships(xml)
      rel1 = Relationships.create_image_relationship("rId1", "media/image1.png")
      rel2 = Relationships.create_image_relationship("rId2", "media/image2.png")
      rel3 = Relationships.create_image_relationship("rId3", "media/image3.png")

      # Act
      updated =
        rels
        |> Relationships.add_relationship(rel1)
        |> Relationships.add_relationship(rel2)
        |> Relationships.add_relationship(rel3)

      # Assert
      ids = Relationships.extract_relationship_ids(updated)
      assert ids == ["rId1", "rId2", "rId3"]
    end

    test "preserves existing relationships when adding new one" do
      # Arrange
      xml = """
      <?xml version="1.0"?>
      <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
        <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/fontTable" Target="fontTable.xml"/>
      </Relationships>
      """

      {:ok, rels} = Relationships.parse_relationships(xml)
      rel = Relationships.create_image_relationship("rId3", "media/logo.png")

      # Act
      updated = Relationships.add_relationship(rels, rel)

      # Assert
      ids = Relationships.extract_relationship_ids(updated)
      assert length(ids) == 3
      assert "rId1" in ids
      assert "rId2" in ids
      assert "rId3" in ids
    end
  end

  describe "serialize_relationships/1" do
    test "serializes empty relationships" do
      # Arrange
      xml = """
      <?xml version="1.0"?>
      <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      </Relationships>
      """

      {:ok, rels} = Relationships.parse_relationships(xml)

      # Act
      result = Relationships.serialize_relationships(rels)

      # Assert
      assert {:ok, serialized} = result
      assert is_binary(serialized)
      assert serialized =~ "Relationships"
    end

    test "serializes relationships with entries" do
      # Arrange
      xml = """
      <?xml version="1.0"?>
      <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://example.com" Target="foo.xml"/>
      </Relationships>
      """

      {:ok, rels} = Relationships.parse_relationships(xml)

      # Act
      {:ok, serialized} = Relationships.serialize_relationships(rels)

      # Assert
      assert serialized =~ "rId1"
      assert serialized =~ "foo.xml"
      assert serialized =~ "http://example.com"
    end

    test "round-trip parse and serialize preserves structure" do
      # Arrange
      original_xml = """
      <?xml version="1.0"?>
      <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://example.com/type1" Target="file1.xml"/>
        <Relationship Id="rId5" Type="http://example.com/type2" Target="media/image.png"/>
      </Relationships>
      """

      # Act
      {:ok, parsed} = Relationships.parse_relationships(original_xml)
      {:ok, serialized} = Relationships.serialize_relationships(parsed)
      {:ok, reparsed} = Relationships.parse_relationships(serialized)

      # Assert
      original_ids = Relationships.extract_relationship_ids(parsed)
      reparsed_ids = Relationships.extract_relationship_ids(reparsed)
      assert original_ids == reparsed_ids
    end

    test "serializes after adding relationships" do
      # Arrange
      xml = """
      <?xml version="1.0"?>
      <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      </Relationships>
      """

      {:ok, rels} = Relationships.parse_relationships(xml)
      rel = Relationships.create_image_relationship("rId1", "media/image1.png")
      updated = Relationships.add_relationship(rels, rel)

      # Act
      {:ok, serialized} = Relationships.serialize_relationships(updated)

      # Assert
      assert serialized =~ "rId1"
      assert serialized =~ "media/image1.png"
      assert serialized =~ "http://schemas.openxmlformats.org/officeDocument/2006/relationships/image"
    end
  end

  describe "integration workflow" do
    test "complete workflow: parse, extract, generate, add, serialize" do
      # Arrange
      xml = """
      <?xml version="1.0"?>
      <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
        <Relationship Id="rId5" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/fontTable" Target="fontTable.xml"/>
      </Relationships>
      """

      # Act - Full workflow
      {:ok, rels} = Relationships.parse_relationships(xml)
      existing_ids = Relationships.extract_relationship_ids(rels)
      new_id = Relationships.generate_unique_id(existing_ids)
      new_rel = Relationships.create_image_relationship(new_id, "media/logo.png")
      updated_rels = Relationships.add_relationship(rels, new_rel)
      {:ok, final_xml} = Relationships.serialize_relationships(updated_rels)

      # Assert
      assert existing_ids == ["rId1", "rId5"]
      assert new_id == "rId6"
      assert final_xml =~ "rId6"
      assert final_xml =~ "media/logo.png"

      # Verify by parsing again
      {:ok, reparsed} = Relationships.parse_relationships(final_xml)
      all_ids = Relationships.extract_relationship_ids(reparsed)
      assert all_ids == ["rId1", "rId5", "rId6"]
    end

    test "handles adding multiple images in sequence" do
      # Arrange
      xml = """
      <?xml version="1.0"?>
      <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      </Relationships>
      """

      {:ok, initial_rels} = Relationships.parse_relationships(xml)

      # Act - Add 3 images
      images = ["logo.png", "banner.jpg", "icon.gif"]

      final_rels =
        Enum.reduce(images, initial_rels, fn image, rels_acc ->
          ids = Relationships.extract_relationship_ids(rels_acc)
          new_id = Relationships.generate_unique_id(ids)
          rel = Relationships.create_image_relationship(new_id, "media/#{image}")
          Relationships.add_relationship(rels_acc, rel)
        end)

      # Assert
      final_ids = Relationships.extract_relationship_ids(final_rels)
      assert final_ids == ["rId1", "rId2", "rId3"]

      {:ok, serialized} = Relationships.serialize_relationships(final_rels)
      assert serialized =~ "logo.png"
      assert serialized =~ "banner.jpg"
      assert serialized =~ "icon.gif"
    end
  end
end
