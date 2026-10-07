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

  @w_ns ~s(xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main")

  defp render_body(body, data) do
    FixtureHelper.create_docx_with_body(@template, body)
    assert :ok = Ootempl.render(@template, data, @output)
    {:ok, xml} = OotemplTestHelpers.extract_file_for_test(@output, "word/document.xml")
    xml
  end

  # Renders a document whose `part` (e.g. "word/header1.xml") holds the given
  # XML and returns that part's rendered XML.
  defp render_part(part, part_xml, data) do
    FixtureHelper.create_docx_with_parts(@template, "<w:p/>", %{part => part_xml})
    assert :ok = Ootempl.render(@template, data, @output)
    {:ok, xml} = OotemplTestHelpers.extract_file_for_test(@output, part)
    xml
  end

  # Runs (as XML strings) of the first paragraph containing `text`.
  defp runs_around(xml, text) do
    ~r{<w:r>.*?</w:r>|<w:r [^>]*>.*?</w:r>}s
    |> Regex.scan(xml)
    |> List.flatten()
    |> Enum.filter(&(&1 =~ text))
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

      assert displayed_text(xml) == "Hello Ann "
      assert xml =~ ~S(<w:t xml:space="preserve"> </w:t>)
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

  describe "conditional sections" do
    test "inline conditional keeps surrounding spaces when true" do
      body =
        ~S(<w:p><w:r><w:t xml:space="preserve">Hello {{if vip}}valued {{endif}}customer</w:t></w:r></w:p>)

      xml = render_body(body, %{"vip" => true})

      assert displayed_text(xml) == "Hello valued customer"
      assert xml =~ ~s(xml:space="preserve")
    end

    test "inline conditional keeps surrounding spaces when false" do
      body =
        ~S(<w:p><w:r><w:t xml:space="preserve">Hello {{if vip}}valued {{endif}}customer</w:t></w:r></w:p>)

      xml = render_body(body, %{"vip" => false})

      assert displayed_text(xml) == "Hello customer"
    end

    test "paragraph inside a true conditional keeps its run structure" do
      body =
        ~S(<w:p><w:r><w:t>{{if vip}}</w:t></w:r></w:p>) <>
          ~S(<w:p><w:r><w:t>Tier:</w:t><w:tab/><w:t xml:space="preserve">{{tier}} </w:t></w:r></w:p>) <>
          ~S(<w:p><w:r><w:t>{{endif}}</w:t></w:r></w:p>)

      xml = render_body(body, %{"vip" => true, "tier" => "Gold"})

      assert xml =~ ~r{Tier:</w:t>\s*<w:tab/>\s*<w:t xml:space="preserve">Gold </w:t>}
    end
  end

  describe "inline conditionals" do
    @if_else ~S(<w:p><w:r><w:t xml:space="preserve">Dear {{if formal}}Sir{{else}}friend{{endif}}, hi</w:t></w:r></w:p>)

    test "if/else keeps the if branch when true" do
      assert @if_else |> render_body(%{"formal" => true}) |> displayed_text() == "Dear Sir, hi"
    end

    test "if/else keeps the else branch when false" do
      assert @if_else |> render_body(%{"formal" => false}) |> displayed_text() == "Dear friend, hi"
    end

    test "a removed branch takes its breaks and runs with it" do
      body =
        ~S(<w:p><w:r><w:t>A{{if x}}</w:t><w:br/><w:t xml:space="preserve">B </w:t></w:r>) <>
          ~S(<w:r><w:rPr><w:b/></w:rPr><w:t>bold</w:t></w:r><w:r><w:t>{{endif}}C</w:t></w:r></w:p>)

      xml = render_body(body, %{"x" => false})

      assert displayed_text(xml) == "AC"
      refute xml =~ "<w:br/>"
      refute xml =~ "<w:b/>"
    end

    test "a kept branch keeps its breaks and formatting" do
      body =
        ~S(<w:p><w:r><w:t>A{{if x}}</w:t><w:br/><w:t xml:space="preserve">B </w:t></w:r>) <>
          ~S(<w:r><w:rPr><w:b/></w:rPr><w:t>bold</w:t></w:r><w:r><w:t>{{endif}}C</w:t></w:r></w:p>)

      xml = render_body(body, %{"x" => true})

      assert displayed_text(xml) == "AB boldC"
      assert xml =~ "<w:br/>"
      assert [bold_run] = runs_around(xml, ">bold<")
      assert bold_run =~ "<w:b/>"
    end

    test "several and nested inline conditionals in one paragraph" do
      body =
        ~S(<w:p><w:r><w:t xml:space="preserve">{{if a}}A{{if b}}B{{endif}}{{endif}} and {{if c}}C{{else}}not C{{endif}}</w:t></w:r></w:p>)

      xml = render_body(body, %{"a" => true, "b" => false, "c" => false})

      assert displayed_text(xml) == "A and not C"
    end

    test "fragmented inline markers are handled" do
      body =
        ~S(<w:p><w:r><w:t xml:space="preserve">Hi {{i</w:t></w:r><w:r><w:t>f vip}}VIP {{end</w:t></w:r>) <>
          ~S(<w:r><w:t>if}}there</w:t></w:r></w:p>)

      assert body |> render_body(%{"vip" => false}) |> displayed_text() == "Hi there"
    end

    test "placeholders inside a kept branch are replaced" do
      body = ~S(<w:p><w:r><w:t xml:space="preserve">Hi{{if vip}} {{name}}{{endif}}!</w:t></w:r></w:p>)

      assert body |> render_body(%{"vip" => true, "name" => "Ann"}) |> displayed_text() == "Hi Ann!"
    end

    test "placeholders inside a removed branch are not required" do
      body = ~S(<w:p><w:r><w:t xml:space="preserve">Hi{{if vip}} {{name}}{{endif}}!</w:t></w:r></w:p>)

      assert body |> render_body(%{"vip" => false}) |> displayed_text() == "Hi!"
    end

    test "inline conditional in a table cell" do
      body =
        ~S(<w:tbl><w:tr><w:tc><w:p><w:r><w:t>{{if paid}}Paid{{else}}Due{{endif}}</w:t></w:r></w:p></w:tc></w:tr></w:tbl>)

      assert body |> render_body(%{"paid" => false}) |> displayed_text() == "Due"
    end

    test "inline conditional in a header" do
      part_xml =
        ~s(<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:hdr #{@w_ns}>) <>
          ~S(<w:p><w:r><w:t>{{if draft}}DRAFT {{endif}}Report</w:t></w:r></w:p></w:hdr>)

      assert "word/header1.xml" |> render_part(part_xml, %{"draft" => false}) |> displayed_text() == "Report"
    end
  end

  describe "paragraph-level conditionals" do
    test "multi-byte characters earlier in the document do not garble the condition" do
      body =
        ~S(<w:p><w:r><w:t>The provider’s résumé</w:t></w:r></w:p>) <>
          ~S(<w:p><w:r><w:t>{{if vip}}</w:t></w:r></w:p><w:p><w:r><w:t>VIP</w:t></w:r></w:p>) <>
          ~S(<w:p><w:r><w:t>{{endif}}</w:t></w:r></w:p>)

      assert body |> render_body(%{"vip" => true}) |> displayed_text() == "The provider’s résuméVIP"
    end

    test "markers are matched case-insensitively and with extra spaces" do
      body =
        ~S(<w:p><w:r><w:t>{{IF  vip}}</w:t></w:r></w:p><w:p><w:r><w:t>VIP</w:t></w:r></w:p>) <>
          ~S(<w:p><w:r><w:t>{{EndIf}}</w:t></w:r></w:p><w:p><w:r><w:t>after</w:t></w:r></w:p>)

      assert body |> render_body(%{"vip" => false}) |> displayed_text() == "after"
    end

    test "a paragraph-level conditional in a header" do
      part_xml =
        ~s(<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:hdr #{@w_ns}>) <>
          ~S(<w:p><w:r><w:t>{{if draft}}</w:t></w:r></w:p><w:p><w:r><w:t>DRAFT</w:t></w:r></w:p>) <>
          ~S(<w:p><w:r><w:t>{{endif}}</w:t></w:r></w:p><w:p><w:r><w:t>Report</w:t></w:r></w:p></w:hdr>)

      assert "word/header1.xml" |> render_part(part_xml, %{"draft" => false}) |> displayed_text() == "Report"
    end

    test "removing a section does not remove identical paragraphs elsewhere" do
      body =
        ~S(<w:p><w:r><w:t>Top</w:t></w:r></w:p><w:p/>) <>
          ~S(<w:p><w:r><w:t>{{if vip}}</w:t></w:r></w:p><w:p/><w:p><w:r><w:t>Thanks</w:t></w:r></w:p>) <>
          ~S(<w:p><w:r><w:t>{{endif}}</w:t></w:r></w:p>) <>
          ~S(<w:p/><w:p><w:r><w:t>Thanks</w:t></w:r></w:p>)

      xml = render_body(body, %{"vip" => false})

      assert displayed_text(xml) == "TopThanks"
      assert length(Regex.scan(~r{<w:p/>}, xml)) == 2
    end

    test "a section between two identical marker paragraphs keeps the other markers' content" do
      body =
        ~S(<w:p><w:r><w:t>{{if a}}</w:t></w:r></w:p><w:p><w:r><w:t>A</w:t></w:r></w:p>) <>
          ~S(<w:p><w:r><w:t>{{endif}}</w:t></w:r></w:p>) <>
          ~S(<w:p><w:r><w:t>{{if a}}</w:t></w:r></w:p><w:p><w:r><w:t>B</w:t></w:r></w:p>) <>
          ~S(<w:p><w:r><w:t>{{endif}}</w:t></w:r></w:p><w:p><w:r><w:t>end</w:t></w:r></w:p>)

      assert body |> render_body(%{"a" => true}) |> displayed_text() == "ABend"
      assert body |> render_body(%{"a" => false}) |> displayed_text() == "end"
    end

    test "a section filling a table cell leaves the cell with a paragraph" do
      body =
        ~S(<w:tbl><w:tr><w:tc><w:p><w:r><w:t>{{if x}}</w:t></w:r></w:p><w:p><w:r><w:t>X</w:t></w:r></w:p>) <>
          ~S(<w:p><w:r><w:t>{{endif}}</w:t></w:r></w:p></w:tc></w:tr></w:tbl>)

      xml = render_body(body, %{"x" => false})

      assert xml =~ ~r{<w:tc><w:p(/>|>.*?</w:p>)</w:tc>}
    end

    test "a marker sharing its paragraph with text across paragraphs is an error, not data loss" do
      body =
        ~S(<w:p><w:r><w:t>Intro {{if vip}}</w:t></w:r></w:p><w:p><w:r><w:t>VIP</w:t></w:r></w:p>) <>
          ~S(<w:p><w:r><w:t>{{endif}}</w:t></w:r></w:p>)

      FixtureHelper.create_docx_with_body(@template, body)

      assert {:error, _reason} = Ootempl.render(@template, %{"vip" => true}, @output)
    end
  end

  describe "whitespace produced by substitution" do
    test "trailing space left by an empty value is preserved" do
      body =
        ~S(<w:p><w:r><w:t>Hello {{name}}</w:t></w:r><w:r><w:rPr><w:b/></w:rPr><w:t>friend</w:t></w:r></w:p>)

      xml = render_body(body, %{"name" => ""})

      assert xml =~ ~s(<w:t xml:space="preserve">Hello </w:t>)
    end

    test "leading and trailing spaces in a value are preserved" do
      body = ~S(<w:p><w:r><w:t>[</w:t></w:r><w:r><w:t>{{v}}</w:t></w:r><w:r><w:t>]</w:t></w:r></w:p>)
      xml = render_body(body, %{"v" => " padded "})

      assert xml =~ ~s(<w:t xml:space="preserve"> padded </w:t>)
    end

    test "a newline in a value becomes a line break" do
      body = ~S(<w:p><w:r><w:t>{{address}}</w:t></w:r></w:p>)
      xml = render_body(body, %{"address" => "123 Main St\nSpringfield"})

      assert xml =~ ~r{123 Main St</w:t>\s*<w:br/>\s*<w:t[^>]*>Springfield</w:t>}
    end

    test "a CRLF in a value becomes a single line break" do
      body = ~S(<w:p><w:r><w:t>{{address}}</w:t></w:r></w:p>)
      xml = render_body(body, %{"address" => "Line 1\r\nLine 2"})

      assert xml =~ ~r{Line 1</w:t>\s*<w:br/>\s*<w:t[^>]*>Line 2</w:t>}
      refute xml =~ "\r"
    end

    test "a tab in a value becomes a tab element" do
      body = ~S(<w:p><w:r><w:t>{{row}}</w:t></w:r></w:p>)
      xml = render_body(body, %{"row" => "Name\tBob"})

      assert xml =~ ~r{Name</w:t>\s*<w:tab/>\s*<w:t[^>]*>Bob</w:t>}
    end
  end

  describe "other run content" do
    test "hyphen, symbol and carriage return elements in a run with a placeholder are kept" do
      body =
        ~S(<w:p><w:r><w:t>{{a}}</w:t><w:noBreakHyphen/><w:softHyphen/>) <>
          ~S(<w:sym w:font="Wingdings" w:char="F0FC"/><w:cr/><w:t>{{b}}</w:t></w:r></w:p>)

      xml = render_body(body, %{"a" => "x", "b" => "y"})

      for tag <- ["<w:noBreakHyphen/>", "<w:softHyphen/>", "<w:sym ", "<w:cr/>"], do: assert(xml =~ tag)
    end

    test "a field next to a placeholder is left intact" do
      body =
        ~S(<w:p><w:r><w:t xml:space="preserve">{{company}} - Page </w:t></w:r>) <>
          ~S(<w:r><w:fldChar w:fldCharType="begin"/></w:r>) <>
          ~S(<w:r><w:instrText xml:space="preserve"> PAGE </w:instrText></w:r>) <>
          ~S(<w:r><w:fldChar w:fldCharType="separate"/></w:r>) <>
          ~S(<w:r><w:t>1</w:t></w:r>) <>
          ~S(<w:r><w:fldChar w:fldCharType="end"/></w:r></w:p>)

      xml = render_body(body, %{"company" => "Acme"})

      assert xml =~ ~s(<w:t xml:space="preserve">Acme - Page </w:t></w:r><w:r><w:fldChar w:fldCharType="begin"/></w:r>)
      assert length(Regex.scan(~r{<w:r>}, xml)) == 6
    end
  end

  describe "runs the normalizer must not remove" do
    test "an empty run in a paragraph with a fragmented placeholder is kept" do
      body =
        ~S(<w:p><w:r><w:rPr><w:b/></w:rPr></w:r><w:r><w:t>{{na</w:t></w:r><w:r><w:t>me}}</w:t></w:r></w:p>)

      xml = render_body(body, %{"name" => "Ann"})

      assert displayed_text(xml) == "Ann"
      assert xml =~ "<w:r><w:rPr><w:b/></w:rPr></w:r>"
    end
  end

  describe "formatting around fragmented placeholders" do
    test "a stray brace does not merge differently formatted runs" do
      body =
        ~S(<w:p><w:r><w:t xml:space="preserve">Use {curly} </w:t></w:r>) <>
          ~S(<w:r><w:rPr><w:b/></w:rPr><w:t>bold</w:t></w:r>) <>
          ~S(<w:r><w:t xml:space="preserve"> then {{x}}</w:t></w:r></w:p>)

      xml = render_body(body, %{"x" => "done"})

      assert displayed_text(xml) == "Use {curly} bold then done"
      assert [bold_run] = runs_around(xml, ">bold<")
      assert bold_run =~ "<w:b/>"
    end

    test "text outside a fragmented placeholder keeps its own formatting" do
      body =
        ~S(<w:p><w:r><w:rPr><w:b/></w:rPr><w:t xml:space="preserve">Dear {{</w:t></w:r>) <>
          ~S(<w:r><w:t>name}}, thanks</w:t></w:r></w:p>)

      xml = render_body(body, %{"name" => "Ann"})

      assert displayed_text(xml) == "Dear Ann, thanks"
      assert [dear_run] = runs_around(xml, "Dear")
      assert dear_run =~ "<w:b/>"
      assert [thanks_run] = runs_around(xml, ", thanks")
      refute thanks_run =~ "<w:b/>"
    end

    test "property values, not just names, distinguish formatting" do
      body =
        ~S(<w:p><w:r><w:rPr><w:sz w:val="32"/></w:rPr><w:t xml:space="preserve">Title {{</w:t></w:r>) <>
          ~S(<w:r><w:rPr><w:sz w:val="20"/></w:rPr><w:t>name}} small print</w:t></w:r></w:p>)

      xml = render_body(body, %{"name" => "Report"})

      assert displayed_text(xml) == "Title Report small print"
      assert [small_run] = runs_around(xml, "small print")
      assert small_run =~ ~s(w:val="20")
    end
  end

  describe "placeholders inside paragraph-level containers" do
    test "fragmented placeholder split by a bookmark is replaced" do
      body =
        ~S(<w:p><w:r><w:t>{{na</w:t></w:r><w:bookmarkStart w:id="0" w:name="b"/>) <>
          ~S(<w:r><w:t>me}}</w:t></w:r><w:bookmarkEnd w:id="0"/></w:p>)

      xml = render_body(body, %{"name" => "Ann"})

      assert displayed_text(xml) == "Ann"
    end

    for {label, open, close} <- [
          {"hyperlink", ~S(<w:hyperlink w:anchor="x">), "</w:hyperlink>"},
          {"tracked insertion", ~S(<w:ins w:id="1" w:author="a">), "</w:ins>"},
          {"inline content control", "<w:sdt><w:sdtContent>", "</w:sdtContent></w:sdt>"},
          {"smart tag", ~S(<w:smartTag w:uri="u" w:element="e">), "</w:smartTag>"}
        ] do
      test "fragmented placeholder inside a #{label} is replaced" do
        body =
          "<w:p>" <>
            unquote(open) <> ~S(<w:r><w:t>{{na</w:t></w:r><w:r><w:t>me}}</w:t></w:r>) <> unquote(close) <> "</w:p>"

        xml = render_body(body, %{"name" => "Ann"})

        assert displayed_text(xml) == "Ann"
      end
    end
  end

  describe "placeholders that cannot be normalized" do
    test "a placeholder split across a hyperlink boundary is reported, not left in the output" do
      body =
        ~S(<w:p><w:r><w:t>{{na</w:t></w:r><w:hyperlink w:anchor="x"><w:r><w:t>me}}</w:t></w:r></w:hyperlink></w:p>)

      FixtureHelper.create_docx_with_body(@template, body)

      assert {:error, %Ootempl.PlaceholderError{placeholders: [%{placeholder: "{{name}}", reason: :split_placeholder}]}} =
               Ootempl.render(@template, %{"name" => "Ann"}, @output)
    end

    test "an escaped placeholder split across runs is not reported" do
      body = ~S(<w:p><w:r><w:t>\{{na</w:t></w:r><w:hyperlink w:anchor="x"><w:r><w:t>me}}</w:t></w:r></w:hyperlink></w:p>)
      xml = render_body(body, %{})

      assert displayed_text(xml) == "{{name}}"
    end
  end

  describe "headers, footers and notes" do
    for {part, root} <- [
          {"word/header1.xml", "w:hdr"},
          {"word/footer1.xml", "w:ftr"}
        ] do
      test "#{part} gets single escaping, preserved spaces and line breaks" do
        part_xml =
          ~s(<?xml version="1.0" encoding="UTF-8" standalone="yes"?><#{unquote(root)} #{@w_ns}>) <>
            ~S(<w:p><w:r><w:t xml:space="preserve">{{company}} </w:t></w:r><w:r><w:t>{{addr}}</w:t></w:r></w:p>) <>
            "</#{unquote(root)}>"

        xml = render_part(unquote(part), part_xml, %{"company" => "A & B", "addr" => "1 Main\nTown"})

        assert xml =~ ~s(<w:t xml:space="preserve">A &amp; B </w:t>)
        assert xml =~ ~r{1 Main</w:t>\s*<w:br/>}
      end
    end

    for {part, root, note} <- [
          {"word/footnotes.xml", "w:footnotes", "w:footnote"},
          {"word/endnotes.xml", "w:endnotes", "w:endnote"}
        ] do
      test "#{part} gets single escaping and preserved spaces" do
        part_xml =
          ~s(<?xml version="1.0" encoding="UTF-8" standalone="yes"?><#{unquote(root)} #{@w_ns}>) <>
            ~s(<#{unquote(note)} w:id="1">) <>
            ~S[<w:p><w:r><w:t xml:space="preserve">Source: {{src}} </w:t></w:r><w:r><w:t>(2025)</w:t></w:r></w:p>] <>
            "</#{unquote(note)}></#{unquote(root)}>"

        xml = render_part(unquote(part), part_xml, %{"src" => "R&D"})

        assert xml =~ ~s(<w:t xml:space="preserve">Source: R&amp;D </w:t>)
      end
    end
  end
end
