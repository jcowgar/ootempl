defmodule Ootempl.Integration.TextFidelityTest do
  @moduledoc """
  End-to-end tests that substituted text reaches the document exactly as
  supplied: XML special characters are escaped once (not twice), and run
  structure that carries meaning (`xml:space="preserve"`, tabs, breaks) is not
  discarded when a run containing a placeholder is rewritten.
  """

  use ExUnit.Case, async: false

  import Ootempl.Xml

  alias Ootempl.FixtureHelper

  require Record

  @template "tmp/text_fidelity_template.docx"
  @output "tmp/text_fidelity_output.docx"

  setup do
    on_exit(fn ->
      File.rm(@template)
      File.rm(@output)
    end)

    :ok
  end

  defp render_body(body, data) do
    FixtureHelper.create_docx_with_body(@template, body)
    assert :ok = Ootempl.render(@template, data, @output)
    {:ok, xml} = OotemplTestHelpers.extract_file_for_test(@output, "word/document.xml")
    xml
  end

  # Text as Word would display it: the parsed (unescaped) content of every
  # <w:t>, in document order.
  defp displayed_text(xml) do
    {:ok, doc} = Ootempl.Xml.parse(xml)
    doc |> collect_text() |> IO.iodata_to_binary()
  end

  defp collect_text(node) do
    cond do
      Record.is_record(node, :xmlElement) and xmlElement(node, :name) == :"w:t" ->
        node
        |> xmlElement(:content)
        |> Enum.filter(&Record.is_record(&1, :xmlText))
        |> Enum.map(&:unicode.characters_to_binary(xmlText(&1, :value)))

      Record.is_record(node, :xmlElement) ->
        node |> xmlElement(:content) |> Enum.map(&collect_text/1)

      true ->
        []
    end
  end

  describe "XML special characters in substituted values" do
    test "ampersand is escaped exactly once" do
      body = ~S(<w:p><w:r><w:t>Policy: {{policy}}</w:t></w:r></w:p>)
      xml = render_body(body, %{"policy" => "EDU&TRN"})

      assert xml =~ "EDU&amp;TRN"
      refute xml =~ "&amp;amp;"
      assert displayed_text(xml) == "Policy: EDU&TRN"
    end

    test "apostrophes and quotes render as typed" do
      body = ~S(<w:p><w:r><w:t>{{note}}</w:t></w:r></w:p>)
      xml = render_body(body, %{"note" => ~S(The provider's "final" notice)})

      refute xml =~ "&amp;apos;"
      refute xml =~ "&amp;quot;"
      assert displayed_text(xml) == ~S(The provider's "final" notice)
    end

    test "angle brackets render as typed" do
      body = ~S(<w:p><w:r><w:t>{{range}}</w:t></w:r></w:p>)
      xml = render_body(body, %{"range" => "<5 and >10"})

      assert displayed_text(xml) == "<5 and >10"
    end

    test "text that already looks like an entity is treated literally" do
      body = ~S(<w:p><w:r><w:t>{{raw}}</w:t></w:r></w:p>)
      xml = render_body(body, %{"raw" => "Tom &amp; Jerry"})

      assert displayed_text(xml) == "Tom &amp; Jerry"
    end

    test "special characters in a repeating table row are escaped once" do
      body = """
      <w:tbl>
        <w:tr><w:tc><w:p><w:r><w:t>{{items.name}}</w:t></w:r></w:p></w:tc></w:tr>
      </w:tbl>
      """

      xml = render_body(body, %{"items" => [%{"name" => "A & B"}, %{"name" => "O'Brien"}]})

      assert displayed_text(xml) == "A & BO'Brien"
    end
  end

  describe "run structure around placeholders" do
    test "xml:space=preserve survives on a run containing a placeholder" do
      body =
        ~S(<w:p><w:r><w:t xml:space="preserve">Dear {{name}}, </w:t></w:r><w:r><w:t>welcome.</w:t></w:r></w:p>)

      xml = render_body(body, %{"name" => "Bob"})

      assert xml =~ ~S(<w:t xml:space="preserve">Dear Bob, </w:t>)
    end

    test "xml:space=preserve survives with a leading space" do
      body = ~S(<w:p><w:r><w:t>Claim</w:t></w:r><w:r><w:t xml:space="preserve"> {{id}}</w:t></w:r></w:p>)
      xml = render_body(body, %{"id" => "22705595"})

      assert xml =~ ~S(<w:t xml:space="preserve"> 22705595</w:t>)
    end

    test "xml:space=preserve survives when a fragmented placeholder is collapsed" do
      body =
        ~S(<w:p><w:r><w:t xml:space="preserve">Hello {{</w:t></w:r><w:proofErr w:type="spellStart"/>) <>
          ~S(<w:r><w:t>first_name</w:t></w:r><w:proofErr w:type="spellEnd"/>) <>
          ~S(<w:r><w:t xml:space="preserve">}} </w:t></w:r></w:p>)

      xml = render_body(body, %{"first_name" => "Ann"})

      assert xml =~ ~S(<w:t xml:space="preserve">Hello Ann </w:t>)
    end

    test "a fragmented placeholder is collapsed when runs are separated by whitespace" do
      body = """
      <w:p>
        <w:r><w:t>Hello {{</w:t></w:r>
        <w:r><w:t>first_name}}</w:t></w:r>
      </w:p>
      """

      xml = render_body(body, %{"first_name" => "Ann"})

      refute xml =~ "{{"
      assert displayed_text(xml) == "Hello Ann"
    end

    test "a tab between fragments of a collapsed span is kept" do
      body =
        ~S(<w:p><w:r><w:t>Name:</w:t><w:tab/><w:t>{{</w:t></w:r><w:r><w:t>name}}</w:t></w:r></w:p>)

      xml = render_body(body, %{"name" => "Bob"})

      assert xml =~ ~r{Name:</w:t>\s*<w:tab/>\s*<w:t[^>]*>Bob</w:t>}
    end

    test "a tab inside a run containing a placeholder is kept" do
      body = ~S(<w:p><w:r><w:t>Name:</w:t><w:tab/><w:t>{{name}}</w:t></w:r></w:p>)
      xml = render_body(body, %{"name" => "Bob"})

      assert xml =~ ~r{Name:</w:t>\s*<w:tab/>\s*<w:t[^>]*>Bob</w:t>}
    end

    test "a line break inside a run containing a placeholder is kept" do
      body = ~S(<w:p><w:r><w:t>{{line1}}</w:t><w:br/><w:t>{{line2}}</w:t></w:r></w:p>)
      xml = render_body(body, %{"line1" => "123 Main St", "line2" => "Springfield"})

      assert xml =~ ~r{123 Main St</w:t>\s*<w:br/>\s*<w:t[^>]*>Springfield</w:t>}
    end
  end
end
