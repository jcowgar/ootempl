defmodule Ootempl.Xml do
  @moduledoc """
  XML manipulation utilities for working with Erlang's `:xmerl` library.

  This module provides Elixir-friendly wrappers around `:xmerl` record structures,
  enabling type-safe XML operations for parsing and manipulating Office document XML.

  ## Record Structures

  Defines Elixir records for the following `:xmerl` types:
  - `:xmlElement` - XML element nodes
  - `:xmlAttribute` - XML attribute nodes
  - `:xmlText` - XML text content nodes

  ## Parsing and Serialization

  Parse XML strings into :xmerl record structures:

      {:ok, doc} = Ootempl.Xml.parse("<root><child>text</child></root>")

  Serialize :xmerl records back to XML strings:

      {:ok, xml_string} = Ootempl.Xml.serialize(doc)

  Round-trip parsing and serialization (useful for testing):

      {:ok, xml_string} = Ootempl.Xml.round_trip("<root><child>text</child></root>")

  All parsing and serialization functions handle XML namespaces correctly,
  which is essential for .docx files that use namespaces extensively (w:, r:, etc.).

  ## Usage

  To use the record macros in your code, you need to import them:

      import Ootempl.Xml

      element = xmlElement(name: :div, content: [])
      name = element_name(element)  # Returns "div"

  See the test suite for comprehensive usage examples.
  """

  require Record

  # Extract record definitions from :xmerl
  Record.defrecord(
    :xmlElement,
    Record.extract(:xmlElement, from_lib: "xmerl/include/xmerl.hrl")
  )

  Record.defrecord(
    :xmlAttribute,
    Record.extract(:xmlAttribute, from_lib: "xmerl/include/xmerl.hrl")
  )

  Record.defrecord(:xmlText, Record.extract(:xmlText, from_lib: "xmerl/include/xmerl.hrl"))

  @type xml_element :: tuple()
  @type xml_attribute :: tuple()
  @type xml_text :: tuple()
  @type xml_node :: xml_element() | xml_text()

  @doc """
  Parses an XML string into :xmerl record structures.

  Uses `:xmerl_scan.string/2` with namespace conformant parsing to correctly
  handle .docx XML which uses namespaces extensively (w:, r:, etc.).

  Returns `{:ok, document}` on success, or `{:error, reason}` if parsing fails.

  ## Examples

      iex> Ootempl.Xml.parse("<root><child>text</child></root>")
      {:ok, {...}}

      iex> Ootempl.Xml.parse("<root><unclosed>")
      {:error, _}
  """
  @spec parse(String.t()) :: {:ok, xml_element()} | {:error, term()}
  def parse(xml_string) when is_binary(xml_string) do
    # :xmerl_scan.string/2 expects a charlist
    # Note: :xmerl has limited UTF-8 support; non-ASCII characters may need
    # the XML declaration with encoding="UTF-8" to parse correctly
    charlist = String.to_charlist(xml_string)
    {doc, _rest} = :xmerl_scan.string(charlist, namespace_conformant: true)
    {:ok, doc}
  rescue
    e -> {:error, e}
  catch
    :exit, reason -> {:error, reason}
  end

  @doc """
  Serializes :xmerl record structures back to an XML string.

  Uses `:xmerl.export_simple/2` to convert the internal representation back
  to XML, preserving namespaces and attributes.

  Returns `{:ok, xml_string}` on success, or `{:error, reason}` if serialization fails.

  ## Examples

      iex> {:ok, doc} = Ootempl.Xml.parse("<root><child>text</child></root>")
      iex> Ootempl.Xml.serialize(doc)
      {:ok, "<?xml version=..."}
  """
  @spec serialize(xml_element()) :: {:ok, String.t()} | {:error, term()}
  def serialize(xml_record) do
    xml_iodata =
      xml_record
      |> List.wrap()
      |> :xmerl.export_simple(:xmerl_xml)

    # Use :unicode.characters_to_binary to handle Unicode codepoints properly
    # :xmerl.export_simple can return iodata with Unicode codepoints > 255
    xml_string = :unicode.characters_to_binary(xml_iodata)

    {:ok, xml_string}
  rescue
    e -> {:error, e}
  catch
    :exit, reason -> {:error, reason}
  end

  @doc """
  Round-trip test helper: parses XML then serializes it back.

  Useful for testing that parsing and serialization preserve XML structure,
  namespaces, and attributes.

  Returns `{:ok, xml_string}` on success, or `{:error, reason}` if either
  parsing or serialization fails.

  ## Examples

      iex> Ootempl.Xml.round_trip("<root><child>text</child></root>")
      {:ok, "<?xml version=..."}
  """
  @spec round_trip(String.t()) :: {:ok, String.t()} | {:error, term()}
  def round_trip(xml_string) do
    with {:ok, doc} <- parse(xml_string) do
      serialize(doc)
    end
  end

  @doc """
  Returns the name of an XML element as a string.

  Converts the atom name to a string, preserving namespaces.
  """
  @spec element_name(xml_element()) :: String.t()
  def element_name(element) do
    element
    |> xmlElement(:name)
    |> Atom.to_string()
  end

  @doc """
  Returns the list of attributes for an XML element.
  """
  @spec element_attributes(xml_element()) :: [xml_attribute()]
  def element_attributes(element) do
    xmlElement(element, :attributes)
  end

  @doc """
  Extracts all text content from an XML element's direct children.

  Returns an empty string if the element contains no text nodes.
  Note: This only extracts text from direct child text nodes, not from nested elements.
  """
  @spec element_text(xml_element()) :: String.t()
  def element_text(element) do
    element
    |> xmlElement(:content)
    |> Enum.filter(&text_node?/1)
    |> Enum.map_join(&text_value/1)
  end

  @doc """
  Finds all direct child elements with the specified name.

  The name can be provided as an atom or string. Returns an empty list
  if no matching elements are found.
  """
  @spec find_elements(xml_element(), atom() | String.t()) :: [xml_element()]
  def find_elements(element, name) when is_binary(name) do
    find_elements(element, String.to_atom(name))
  end

  def find_elements(element, name) when is_atom(name) do
    element
    |> xmlElement(:content)
    |> Enum.filter(fn node ->
      element_node?(node) && xmlElement(node, :name) == name
    end)
  end

  @doc """
  Gets the value of an attribute by name.

  Returns `{:ok, value}` if the attribute exists, or `{:error, :not_found}` if it doesn't.
  The attribute name can be provided as an atom or string.
  """
  @spec get_attribute(xml_element(), atom() | String.t()) ::
          {:ok, String.t()} | {:error, :not_found}
  def get_attribute(element, attr_name) when is_binary(attr_name) do
    get_attribute(element, String.to_atom(attr_name))
  end

  def get_attribute(element, attr_name) when is_atom(attr_name) do
    element
    |> element_attributes()
    |> Enum.find(fn attr -> xmlAttribute(attr, :name) == attr_name end)
    |> case do
      nil -> {:error, :not_found}
      attr -> {:ok, attr |> xmlAttribute(:value) |> List.to_string()}
    end
  end

  @doc """
  Removes a list of nodes from an XML element.

  Traverses the element's content and removes all nodes that match
  any node in the `nodes_to_remove` list. This is useful for removing
  conditional sections when conditions are false.

  ## Parameters

  - `element` - The XML element to process
  - `nodes_to_remove` - List of nodes to remove from the element

  ## Returns

  The modified XML element with the specified nodes removed.

  ## Examples

      iex> {:ok, doc} = Ootempl.Xml.parse("<root><p>keep</p><p>remove</p></root>")
      iex> [keep, remove] = Ootempl.Xml.find_elements(doc, :p)
      iex> modified = Ootempl.Xml.remove_nodes(doc, [remove])
      iex> Ootempl.Xml.find_elements(modified, :p) |> length()
      1
  """
  @spec remove_nodes(xml_element(), [xml_node()]) :: xml_element()
  def remove_nodes(element, nodes_to_remove) do
    content = xmlElement(element, :content)
    filtered_content = filter_and_recurse(content, nodes_to_remove)
    xmlElement(element, content: filtered_content)
  end

  @doc """
  Removes text nodes containing specific marker text from an XML element.

  Recursively traverses the element and removes any text nodes that contain
  the specified marker text. This is useful for removing conditional markers
  when conditions are true (keeping the content but removing the markers).

  ## Parameters

  - `element` - The XML element to process
  - `marker_text` - The text to search for in text nodes (e.g., "@if:active@")

  ## Returns

  The modified XML element with marker text nodes removed.

  ## Examples

      iex> {:ok, doc} = Ootempl.Xml.parse("<root><p>@if:x@</p><p>keep</p></root>")
      iex> modified = Ootempl.Xml.remove_text_nodes_containing(doc, "@if:x@")
      # Text node containing "@if:x@" is removed
  """
  @spec remove_text_nodes_containing(xml_element(), String.t()) :: xml_element()
  def remove_text_nodes_containing(element, marker_text) do
    content = xmlElement(element, :content)
    filtered_content = filter_text_nodes(content, marker_text)
    xmlElement(element, content: filtered_content)
  end

  # Private helpers

  # Filters nodes and recursively processes element children
  @spec filter_and_recurse([xml_node()], [xml_node()]) :: [xml_node()]
  defp filter_and_recurse(nodes, nodes_to_remove) do
    nodes
    |> Enum.reject(fn node -> node in nodes_to_remove end)
    |> Enum.map(fn node ->
      if element_node?(node) do
        remove_nodes(node, nodes_to_remove)
      else
        node
      end
    end)
  end

  # Filters text nodes containing marker text and recursively processes element children
  @spec filter_text_nodes([xml_node()], String.t()) :: [xml_node()]
  defp filter_text_nodes(nodes, marker_text) do
    nodes
    |> Enum.reject(fn node ->
      text_node?(node) && String.contains?(text_value(node), marker_text)
    end)
    |> Enum.map(fn node ->
      if element_node?(node) do
        remove_text_nodes_containing(node, marker_text)
      else
        node
      end
    end)
  end

  @spec element_node?(xml_node()) :: boolean()
  defp element_node?(node) do
    Record.is_record(node, :xmlElement)
  end

  @spec text_node?(xml_node()) :: boolean()
  defp text_node?(node) do
    Record.is_record(node, :xmlText)
  end

  @spec text_value(xml_text()) :: String.t()
  defp text_value(text_node) do
    text_node
    |> xmlText(:value)
    |> List.to_string()
  end
end
