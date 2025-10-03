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
    |> Enum.filter(&is_text_node?/1)
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
      is_element_node?(node) && xmlElement(node, :name) == name
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

  # Private helpers

  @spec is_element_node?(xml_node()) :: boolean()
  defp is_element_node?(node) do
    Record.is_record(node, :xmlElement)
  end

  @spec is_text_node?(xml_node()) :: boolean()
  defp is_text_node?(node) do
    Record.is_record(node, :xmlText)
  end

  @spec text_value(xml_text()) :: String.t()
  defp text_value(text_node) do
    text_node
    |> xmlText(:value)
    |> List.to_string()
  end
end
