defmodule Ootempl.Relationships do
  @moduledoc """
  Manages relationship XML for Office documents.

  This module provides functions to parse, modify, and generate relationship IDs
  in `.docx` relationship files (`word/_rels/document.xml.rels`). Relationships
  link the main document to media files, styles, and other resources using unique
  IDs like `rId1`, `rId2`, etc.

  ## Relationship Structure

  Relationship files follow the OpenXML format:

      <?xml version="1.0"?>
      <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
        <Relationship Id="rId5" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/image1.png"/>
      </Relationships>

  ## Usage

  Parse a relationship file:

      {:ok, rels} = Relationships.parse_relationships(xml_string)

  Extract existing IDs:

      ids = Relationships.extract_relationship_ids(rels)
      # ["rId1", "rId5"]

  Generate a new unique ID:

      new_id = Relationships.generate_unique_id(ids)
      # "rId6"

  Create an image relationship:

      rel = Relationships.create_image_relationship(new_id, "media/image2.png")

  Add the relationship to the XML:

      updated_rels = Relationships.add_relationship(rels, rel)

  Serialize back to XML string:

      {:ok, xml_string} = Relationships.serialize_relationships(updated_rels)
  """

  import Ootempl.Xml

  @type relationship :: %{
          id: String.t(),
          type: String.t(),
          target: String.t()
        }

  @image_relationship_type "http://schemas.openxmlformats.org/officeDocument/2006/relationships/image"

  @doc """
  Parses relationship XML into an :xmerl element structure.

  Returns `{:ok, xml_element}` on success, or `{:error, reason}` if parsing fails.

  ## Examples

      iex> xml = ~s(<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"></Relationships>)
      iex> {:ok, _rels} = Ootempl.Relationships.parse_relationships(xml)
  """
  @spec parse_relationships(String.t()) :: {:ok, Ootempl.Xml.xml_element()} | {:error, term()}
  def parse_relationships(xml_string) when is_binary(xml_string) do
    Ootempl.Xml.parse(xml_string)
  end

  @doc """
  Extracts all relationship IDs from a relationship XML element.

  Returns a list of relationship ID strings like `["rId1", "rId2", "rId5"]`.

  ## Examples

      iex> xml = ~s(<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://example.com" Target="foo.xml"/></Relationships>)
      iex> {:ok, rels} = Ootempl.Relationships.parse_relationships(xml)
      iex> Ootempl.Relationships.extract_relationship_ids(rels)
      ["rId1"]
  """
  @spec extract_relationship_ids(Ootempl.Xml.xml_element()) :: [String.t()]
  def extract_relationship_ids(rels_xml) do
    rels_xml
    |> Ootempl.Xml.find_elements(:Relationship)
    |> Enum.map(fn rel ->
      case Ootempl.Xml.get_attribute(rel, :Id) do
        {:ok, id} -> id
        {:error, :not_found} -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Generates a unique relationship ID given a list of existing IDs.

  Extracts the numeric part from existing IDs (e.g., `"rId5"` → `5`),
  finds the maximum, and increments it to generate a new unique ID.

  Returns `"rId1"` if no existing IDs are provided.

  ## Examples

      iex> Ootempl.Relationships.generate_unique_id([])
      "rId1"

      iex> Ootempl.Relationships.generate_unique_id(["rId1", "rId5"])
      "rId6"

      iex> Ootempl.Relationships.generate_unique_id(["rId1", "rId5", "rId20"])
      "rId21"
  """
  @spec generate_unique_id([String.t()]) :: String.t()
  def generate_unique_id([]), do: "rId1"

  def generate_unique_id(existing_ids) when is_list(existing_ids) do
    max_number =
      existing_ids
      |> Enum.map(&extract_id_number/1)
      |> Enum.max()

    generate_non_colliding_id(max_number + 1, existing_ids)
  end

  @doc """
  Creates an image relationship entry.

  Returns a relationship map with the specified ID and target path.
  The relationship type is automatically set to the OpenXML image relationship type.

  ## Examples

      iex> Ootempl.Relationships.create_image_relationship("rId10", "media/image1.png")
      %{
        id: "rId10",
        type: "http://schemas.openxmlformats.org/officeDocument/2006/relationships/image",
        target: "media/image1.png"
      }
  """
  @spec create_image_relationship(String.t(), String.t()) :: relationship()
  def create_image_relationship(id, target)
      when is_binary(id) and is_binary(target) do
    %{
      id: id,
      type: @image_relationship_type,
      target: target
    }
  end

  @doc """
  Adds a relationship to the relationship XML element.

  Creates a new `<Relationship>` element and appends it to the `<Relationships>` root.

  Returns the updated XML element with the new relationship added.

  ## Examples

      iex> xml = ~s(<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"></Relationships>)
      iex> {:ok, rels} = Ootempl.Relationships.parse_relationships(xml)
      iex> rel = Ootempl.Relationships.create_image_relationship("rId1", "media/image1.png")
      iex> updated = Ootempl.Relationships.add_relationship(rels, rel)
      iex> Ootempl.Relationships.extract_relationship_ids(updated)
      ["rId1"]
  """
  @spec add_relationship(Ootempl.Xml.xml_element(), relationship()) ::
          Ootempl.Xml.xml_element()
  def add_relationship(rels_xml, relationship) do
    # Create the new Relationship element
    new_rel_element =
      xmlElement(
        name: :Relationship,
        attributes: [
          xmlAttribute(name: :Id, value: String.to_charlist(relationship.id)),
          xmlAttribute(name: :Type, value: String.to_charlist(relationship.type)),
          xmlAttribute(name: :Target, value: String.to_charlist(relationship.target))
        ],
        content: [],
        namespace: xmlElement(rels_xml, :namespace)
      )

    # Add the new element to the Relationships content
    current_content = xmlElement(rels_xml, :content)
    updated_content = current_content ++ [new_rel_element]

    xmlElement(rels_xml, content: updated_content)
  end

  @doc """
  Serializes relationship XML back to an XML string.

  Returns `{:ok, xml_string}` on success, or `{:error, reason}` if serialization fails.

  ## Examples

      iex> xml = ~s(<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://example.com" Target="foo.xml"/></Relationships>)
      iex> {:ok, rels} = Ootempl.Relationships.parse_relationships(xml)
      iex> {:ok, serialized} = Ootempl.Relationships.serialize_relationships(rels)
      iex> String.contains?(serialized, "rId1")
      true
  """
  @spec serialize_relationships(Ootempl.Xml.xml_element()) ::
          {:ok, String.t()} | {:error, term()}
  def serialize_relationships(rels_xml) do
    Ootempl.Xml.serialize(rels_xml)
  end

  @doc """
  Validates the structure of a relationship XML element.

  Checks that:
  - The root element is named `Relationships`
  - All `Relationship` children have required attributes: `Id`, `Type`, `Target`

  Returns `:ok` if valid, or `{:error, reason}` if validation fails.

  ## Examples

      iex> xml = ~s(<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"></Relationships>)
      iex> {:ok, rels} = Ootempl.Relationships.parse_relationships(xml)
      iex> Ootempl.Relationships.validate_relationships(rels)
      :ok
  """
  @spec validate_relationships(Ootempl.Xml.xml_element()) :: :ok | {:error, String.t()}
  def validate_relationships(rels_xml) do
    with :ok <- validate_root_element(rels_xml) do
      validate_relationship_elements(rels_xml)
    end
  end

  # Private helpers

  @spec generate_non_colliding_id(integer(), [String.t()]) :: String.t()
  defp generate_non_colliding_id(number, existing_ids) do
    candidate = "rId#{number}"

    if candidate in existing_ids do
      generate_non_colliding_id(number + 1, existing_ids)
    else
      candidate
    end
  end

  @spec extract_id_number(String.t()) :: integer()
  defp extract_id_number(id) do
    case id |> String.replace_prefix("rId", "") |> Integer.parse() do
      {number, ""} when number > 0 -> number
      _ -> 0
    end
  end

  @spec validate_root_element(Ootempl.Xml.xml_element()) :: :ok | {:error, String.t()}
  defp validate_root_element(rels_xml) do
    name = Ootempl.Xml.element_name(rels_xml)

    if name == "Relationships" do
      :ok
    else
      {:error, "Root element must be 'Relationships', got '#{name}'"}
    end
  end

  @spec validate_relationship_elements(Ootempl.Xml.xml_element()) ::
          :ok | {:error, String.t()}
  defp validate_relationship_elements(rels_xml) do
    rels_xml
    |> Ootempl.Xml.find_elements(:Relationship)
    |> Enum.reduce_while(:ok, fn rel, _acc ->
      case validate_relationship_attributes(rel) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  @spec validate_relationship_attributes(Ootempl.Xml.xml_element()) ::
          :ok | {:error, String.t()}
  defp validate_relationship_attributes(rel) do
    required_attrs = [:Id, :Type, :Target]

    missing_attrs =
      Enum.reject(required_attrs, fn attr ->
        match?({:ok, _}, Ootempl.Xml.get_attribute(rel, attr))
      end)

    if Enum.empty?(missing_attrs) do
      :ok
    else
      missing = Enum.map_join(missing_attrs, ", ", &to_string/1)
      {:error, "Relationship missing required attributes: #{missing}"}
    end
  end
end
