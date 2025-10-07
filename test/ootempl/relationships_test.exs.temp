defmodule Ootempl.RelationshipsTest do
  use ExUnit.Case, async: true

  alias Ootempl.Relationships

  @relationships_namespace "http://schemas.openxmlformats.org/package/2006/relationships"
  @image_type "http://schemas.openxmlformats.org/officeDocument/2006/relationships/image"
  @styles_type "http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles"

  # Sample XML fixtures
  @empty_relationships ~s(<?xml version="1.0"?>
<Relationships xmlns="#{@relationships_namespace}">
</Relationships>)

  @single_relationship ~s(<?xml version="1.0"?>
<Relationships xmlns="#{@relationships_namespace}">
  <Relationship Id="rId1" Type="#{@styles_type}" Target="styles.xml"/>
</Relationships>)

  @multiple_relationships ~s(<?xml version="1.0"?>
<Relationships xmlns="#{@relationships_namespace}">
  <Relationship Id="rId1" Type="#{@styles_type}" Target="styles.xml"/>
  <Relationship Id="rId5" Type="#{@image_type}" Target="media/image1.png"/>
</Relationships>)

  @non_sequential_ids ~s(<?xml version="1.0"?>
<Relationships xmlns="#{@relationships_namespace}">
  <Relationship Id="rId1" Type="#{@styles_type}" Target="styles.xml"/>
  <Relationship Id="rId5" Type="#{@image_type}" Target="media/image1.png"/>
  <Relationship Id="rId20" Type="#{@image_type}" Target="media/image2.png"/>
</Relationships>)

  @large_id_numbers ~s(<?xml version="1.0"?>
<Relationships xmlns="#{@relationships_namespace}">
  <Relationship Id="rId999" Type="#{@styles_type}" Target="styles.xml"/>
  <Relationship Id="rId1000" Type="#{@image_type}" Target="media/image1.png"/>
</Relationships>)

  describe "parse_relationships/1" do
    # Arrange, Act, Assert pattern

    test "parses empty relationships file" do
      # Arrange
      xml = @empty_relationships

      # Act
      result = Relationships.parse_relationships(xml)

      # Assert
      assert {:ok, rels} = result
      assert Ootempl.Xml.element_name(rels) == "Relationships"
    end

    test "parses single relationship" do
      # Arrange
      xml = @single_relationship

      # Act
      result = Relationships.parse_relationships(xml)

      # Assert
      assert {:ok, rels} = result
      assert Ootempl.Xml.element_name(rels) == "Relationships"
      rel_elements = Ootempl.Xml.find_elements(rels, :Relationship)
      assert length(rel_elements) == 1
    end

    test "parses multiple relationships" do
      # Arrange
      xml = @multiple_relationships

      # Act
      result = Relationships.parse_relationships(xml)

      # Assert
      assert {:ok, rels} = result
      rel_elements = Ootempl.Xml.find_elements(rels, :Relationship)
      assert length(rel_elements) == 2
    end

    test "returns error for malformed XML" do
      # Arrange
      xml = "<Relationships><Relationship"

      # Act
      result = Relationships.parse_relationships(xml)

      # Assert
      assert {:error, _reason} = result
    end

    test "preserves namespace in parsed XML" do
      # Arrange
      xml = @single_relationship

      # Act
      {:ok, rels} = Relationships.parse_relationships(xml)

      # Assert
      # Serialize and verify namespace is preserved
      {:ok, serialized} = Relationships.serialize_relationships(rels)
      assert String.contains?(serialized, @relationships_namespace)
    end
  end

  describe "extract_relationship_ids/1" do
    test "extracts IDs from empty relationships" do
      # Arrange
      {:ok, rels} = Relationships.parse_relationships(@empty_relationships)

      # Act
      ids = Relationships.extract_relationship_ids(rels)

      # Assert
      assert ids == []
    end

    test "extracts single relationship ID" do
      # Arrange
      {:ok, rels} = Relationships.parse_relationships(@single_relationship)

      # Act
      ids = Relationships.extract_relationship_ids(rels)

      # Assert
      assert ids == ["rId1"]
    end

    test "extracts multiple relationship IDs" do
      # Arrange
      {:ok, rels} = Relationships.parse_relationships(@multiple_relationships)

      # Act
      ids = Relationships.extract_relationship_ids(rels)

      # Assert
      assert ids == ["rId1", "rId5"]
    end

    test "extracts non-sequential IDs" do
      # Arrange
      {:ok, rels} = Relationships.parse_relationships(@non_sequential_ids)

      # Act
      ids = Relationships.extract_relationship_ids(rels)

      # Assert
      assert ids == ["rId1", "rId5", "rId20"]
    end

    test "extracts large ID numbers" do
      # Arrange
      {:ok, rels} = Relationships.parse_relationships(@large_id_numbers)

      # Act
      ids = Relationships.extract_relationship_ids(rels)

      # Assert
      assert ids == ["rId999", "rId1000"]
    end
  end

  describe "generate_unique_id/1" do
    test "generates rId1 for empty list" do
      # Arrange
      existing_ids = []

      # Act
      new_id = Relationships.generate_unique_id(existing_ids)

      # Assert
      assert new_id == "rId1"
    end

    test "generates next sequential ID" do
      # Arrange
      existing_ids = ["rId1", "rId2", "rId3"]

      # Act
      new_id = Relationships.generate_unique_id(existing_ids)

      # Assert
      assert new_id == "rId4"
    end

    test "generates ID after non-sequential IDs" do
      # Arrange
      existing_ids = ["rId1", "rId5", "rId20"]

      # Act
      new_id = Relationships.generate_unique_id(existing_ids)

      # Assert
      assert new_id == "rId21"
    end

    test "generates ID after large numbers" do
      # Arrange
      existing_ids = ["rId999", "rId1000"]

      # Act
      new_id = Relationships.generate_unique_id(existing_ids)

      # Assert
      assert new_id == "rId1001"
    end

    test "generates unique ID with gaps in numbering" do
      # Arrange
      existing_ids = ["rId1", "rId10", "rId5"]

      # Act
      new_id = Relationships.generate_unique_id(existing_ids)

      # Assert
      assert new_id == "rId11"
    end

    test "generates unique IDs in sequence without collisions" do
      # Arrange
      existing_ids = ["rId1", "rId2"]

      # Act
      id1 = Relationships.generate_unique_id(existing_ids)
      id2 = Relationships.generate_unique_id(existing_ids ++ [id1])
      id3 = Relationships.generate_unique_id(existing_ids ++ [id1, id2])

      # Assert
      assert id1 == "rId3"
      assert id2 == "rId4"
      assert id3 == "rId5"
      # Verify no collisions
      all_ids = existing_ids ++ [id1, id2, id3]
      assert length(all_ids) == length(Enum.uniq(all_ids))
    end

    test "handles non-numeric relationship IDs gracefully" do
      # Arrange - Mix of numeric and non-numeric IDs
      existing_ids = ["rId1", "rIdCustom", "rId5", "rIdABC123"]

      # Act
      new_id = Relationships.generate_unique_id(existing_ids)

      # Assert - Should generate rId6 (max numeric is 5)
      assert new_id == "rId6"
      # Verify no collision with any existing ID
      refute new_id in existing_ids
    end

    test "handles malformed IDs without crashing" do
      # Arrange - Various malformed ID formats
      existing_ids = ["rId1", "rIdABC", "Id5", "rId", "custom_id", "rId2extra"]

      # Act - Should not crash
      new_id = Relationships.generate_unique_id(existing_ids)

      # Assert - Should generate based on max valid numeric ID (rId1 -> 1)
      assert new_id == "rId2"
      refute new_id in existing_ids
    end

    test "avoids collision with non-numeric ID that looks like next numeric ID" do
      # Arrange - rId2 exists as custom (non-numeric) ID
      existing_ids = ["rId1", "rId2", "rId5"]

      # Act
      new_id = Relationships.generate_unique_id(existing_ids)

      # Assert - Should generate rId6, not rId2 (which already exists)
      assert new_id == "rId6"
      refute new_id in existing_ids
    end

    test "handles all non-numeric IDs" do
      # Arrange - No numeric IDs at all
      existing_ids = ["rIdCustom", "rIdSpecial", "myRelationship"]

      # Act
      new_id = Relationships.generate_unique_id(existing_ids)

      # Assert - Should start from rId1
      assert new_id == "rId1"
      refute new_id in existing_ids
    end

    test "handles empty string after rId prefix" do
      # Arrange
      existing_ids = ["rId", "rId1", "rId2"]

      # Act
      new_id = Relationships.generate_unique_id(existing_ids)

      # Assert
      assert new_id == "rId3"
    end

    test "handles negative numbers in IDs" do
      # Arrange - IDs with negative numbers (invalid but shouldn't crash)
      existing_ids = ["rId-1", "rId1", "rId5"]

      # Act
      new_id = Relationships.generate_unique_id(existing_ids)

      # Assert - Should generate based on max valid positive numeric ID
      assert new_id == "rId6"
    end
  end

  describe "create_image_relationship/2" do
    test "creates image relationship with correct structure" do
      # Arrange
      id = "rId10"
      target = "media/image1.png"

      # Act
      rel = Relationships.create_image_relationship(id, target)

      # Assert
      assert rel.id == "rId10"
      assert rel.type == @image_type
      assert rel.target == "media/image1.png"
    end

    test "creates image relationship with different target" do
      # Arrange
      id = "rId5"
      target = "media/photo.jpg"

      # Act
      rel = Relationships.create_image_relationship(id, target)

      # Assert
      assert rel.id == "rId5"
      assert rel.target == "media/photo.jpg"
    end

    test "creates image relationship with subdirectory path" do
      # Arrange
      id = "rId20"
      target = "media/subfolder/image.gif"

      # Act
      rel = Relationships.create_image_relationship(id, target)

      # Assert
      assert rel.target == "media/subfolder/image.gif"
    end
  end

  describe "add_relationship/2" do
    test "adds relationship to empty relationships" do
      # Arrange
      {:ok, rels} = Relationships.parse_relationships(@empty_relationships)
      rel = Relationships.create_image_relationship("rId1", "media/image1.png")

      # Act
      updated = Relationships.add_relationship(rels, rel)

      # Assert
      ids = Relationships.extract_relationship_ids(updated)
      assert ids == ["rId1"]
    end

    test "adds relationship to existing relationships" do
      # Arrange
      {:ok, rels} = Relationships.parse_relationships(@multiple_relationships)
      rel = Relationships.create_image_relationship("rId6", "media/image2.png")

      # Act
      updated = Relationships.add_relationship(rels, rel)

      # Assert
      ids = Relationships.extract_relationship_ids(updated)
      assert "rId6" in ids
      assert length(ids) == 3
    end

    test "preserves existing relationships when adding new one" do
      # Arrange
      {:ok, rels} = Relationships.parse_relationships(@multiple_relationships)
      rel = Relationships.create_image_relationship("rId10", "media/new.png")

      # Act
      updated = Relationships.add_relationship(rels, rel)

      # Assert
      ids = Relationships.extract_relationship_ids(updated)
      assert "rId1" in ids
      assert "rId5" in ids
      assert "rId10" in ids
    end

    test "added relationship has correct attributes" do
      # Arrange
      {:ok, rels} = Relationships.parse_relationships(@empty_relationships)
      rel = Relationships.create_image_relationship("rId1", "media/test.png")

      # Act
      updated = Relationships.add_relationship(rels, rel)

      # Assert
      rel_elements = Ootempl.Xml.find_elements(updated, :Relationship)
      [added_rel] = rel_elements

      assert {:ok, "rId1"} = Ootempl.Xml.get_attribute(added_rel, :Id)
      assert {:ok, @image_type} = Ootempl.Xml.get_attribute(added_rel, :Type)
      assert {:ok, "media/test.png"} = Ootempl.Xml.get_attribute(added_rel, :Target)
    end

    test "can add multiple relationships sequentially" do
      # Arrange
      {:ok, rels} = Relationships.parse_relationships(@empty_relationships)
      rel1 = Relationships.create_image_relationship("rId1", "media/image1.png")
      rel2 = Relationships.create_image_relationship("rId2", "media/image2.png")

      # Act
      updated =
        rels
        |> Relationships.add_relationship(rel1)
        |> Relationships.add_relationship(rel2)

      # Assert
      ids = Relationships.extract_relationship_ids(updated)
      assert ids == ["rId1", "rId2"]
    end
  end

  describe "serialize_relationships/1" do
    test "serializes empty relationships" do
      # Arrange
      {:ok, rels} = Relationships.parse_relationships(@empty_relationships)

      # Act
      result = Relationships.serialize_relationships(rels)

      # Assert
      assert {:ok, xml} = result
      assert String.contains?(xml, "Relationships")
      assert String.contains?(xml, @relationships_namespace)
    end

    test "serializes relationship with attributes" do
      # Arrange
      {:ok, rels} = Relationships.parse_relationships(@single_relationship)

      # Act
      {:ok, xml} = Relationships.serialize_relationships(rels)

      # Assert
      assert String.contains?(xml, "rId1")
      assert String.contains?(xml, "styles.xml")
    end

    test "round-trip preserves relationship data" do
      # Arrange
      original = @multiple_relationships
      {:ok, rels} = Relationships.parse_relationships(original)

      # Act
      {:ok, serialized} = Relationships.serialize_relationships(rels)
      {:ok, reparsed} = Relationships.parse_relationships(serialized)

      # Assert
      original_ids = Relationships.extract_relationship_ids(rels)
      reparsed_ids = Relationships.extract_relationship_ids(reparsed)
      assert original_ids == reparsed_ids
    end

    test "serializes added relationships correctly" do
      # Arrange
      {:ok, rels} = Relationships.parse_relationships(@empty_relationships)
      rel = Relationships.create_image_relationship("rId1", "media/image1.png")
      updated = Relationships.add_relationship(rels, rel)

      # Act
      {:ok, xml} = Relationships.serialize_relationships(updated)

      # Assert
      assert String.contains?(xml, "rId1")
      assert String.contains?(xml, "media/image1.png")
      assert String.contains?(xml, @image_type)
    end
  end

  describe "validate_relationships/1" do
    test "validates empty relationships" do
      # Arrange
      {:ok, rels} = Relationships.parse_relationships(@empty_relationships)

      # Act
      result = Relationships.validate_relationships(rels)

      # Assert
      assert result == :ok
    end

    test "validates relationships with correct structure" do
      # Arrange
      {:ok, rels} = Relationships.parse_relationships(@multiple_relationships)

      # Act
      result = Relationships.validate_relationships(rels)

      # Assert
      assert result == :ok
    end

    test "returns error for incorrect root element" do
      # Arrange
      xml = ~s(<?xml version="1.0"?><WrongRoot xmlns="#{@relationships_namespace}"></WrongRoot>)
      {:ok, wrong_root} = Relationships.parse_relationships(xml)

      # Act
      result = Relationships.validate_relationships(wrong_root)

      # Assert
      assert {:error, message} = result
      assert String.contains?(message, "Root element must be 'Relationships'")
    end

    test "returns error for relationship missing Id attribute" do
      # Arrange
      xml = ~s(<?xml version="1.0"?>
<Relationships xmlns="#{@relationships_namespace}">
  <Relationship Type="#{@image_type}" Target="media/image1.png"/>
</Relationships>)
      {:ok, rels} = Relationships.parse_relationships(xml)

      # Act
      result = Relationships.validate_relationships(rels)

      # Assert
      assert {:error, message} = result
      assert String.contains?(message, "missing required attributes")
      assert String.contains?(message, "Id")
    end

    test "returns error for relationship missing Type attribute" do
      # Arrange
      xml = ~s(<?xml version="1.0"?>
<Relationships xmlns="#{@relationships_namespace}">
  <Relationship Id="rId1" Target="media/image1.png"/>
</Relationships>)
      {:ok, rels} = Relationships.parse_relationships(xml)

      # Act
      result = Relationships.validate_relationships(rels)

      # Assert
      assert {:error, message} = result
      assert String.contains?(message, "Type")
    end

    test "returns error for relationship missing Target attribute" do
      # Arrange
      xml = ~s(<?xml version="1.0"?>
<Relationships xmlns="#{@relationships_namespace}">
  <Relationship Id="rId1" Type="#{@image_type}"/>
</Relationships>)
      {:ok, rels} = Relationships.parse_relationships(xml)

      # Act
      result = Relationships.validate_relationships(rels)

      # Assert
      assert {:error, message} = result
      assert String.contains?(message, "Target")
    end

    test "validates relationships after adding new one" do
      # Arrange
      {:ok, rels} = Relationships.parse_relationships(@empty_relationships)
      rel = Relationships.create_image_relationship("rId1", "media/image1.png")
      updated = Relationships.add_relationship(rels, rel)

      # Act
      result = Relationships.validate_relationships(updated)

      # Assert
      assert result == :ok
    end
  end

  describe "integration tests" do
    test "complete workflow: parse, extract, generate, create, add, serialize" do
      # Arrange
      {:ok, rels} = Relationships.parse_relationships(@multiple_relationships)

      # Act
      existing_ids = Relationships.extract_relationship_ids(rels)
      new_id = Relationships.generate_unique_id(existing_ids)
      new_rel = Relationships.create_image_relationship(new_id, "media/logo.png")
      updated_rels = Relationships.add_relationship(rels, new_rel)
      {:ok, xml} = Relationships.serialize_relationships(updated_rels)

      # Assert
      assert new_id == "rId6"
      assert String.contains?(xml, "rId6")
      assert String.contains?(xml, "media/logo.png")

      # Verify by re-parsing
      {:ok, reparsed} = Relationships.parse_relationships(xml)
      final_ids = Relationships.extract_relationship_ids(reparsed)
      assert "rId6" in final_ids
      assert length(final_ids) == 3
    end

    test "handles multiple image additions" do
      # Arrange
      {:ok, rels} = Relationships.parse_relationships(@empty_relationships)

      # Act - Add 5 images
      updated_rels =
        Enum.reduce(1..5, rels, fn i, acc ->
          ids = Relationships.extract_relationship_ids(acc)
          new_id = Relationships.generate_unique_id(ids)
          rel = Relationships.create_image_relationship(new_id, "media/image#{i}.png")
          Relationships.add_relationship(acc, rel)
        end)

      # Assert
      final_ids = Relationships.extract_relationship_ids(updated_rels)
      assert length(final_ids) == 5
      assert final_ids == ["rId1", "rId2", "rId3", "rId4", "rId5"]

      # Verify serialization
      {:ok, xml} = Relationships.serialize_relationships(updated_rels)
      assert String.contains?(xml, "media/image1.png")
      assert String.contains?(xml, "media/image5.png")
    end

    test "preserves non-image relationships" do
      # Arrange
      {:ok, rels} = Relationships.parse_relationships(@multiple_relationships)

      # Act
      ids = Relationships.extract_relationship_ids(rels)
      new_id = Relationships.generate_unique_id(ids)
      rel = Relationships.create_image_relationship(new_id, "media/new.png")
      updated = Relationships.add_relationship(rels, rel)
      {:ok, xml} = Relationships.serialize_relationships(updated)

      # Assert - Original relationships should still be present
      assert String.contains?(xml, "styles.xml")
      assert String.contains?(xml, "rId1")
      assert String.contains?(xml, "rId5")
      assert String.contains?(xml, "rId6")
    end
  end
end
