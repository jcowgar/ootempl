defmodule Ootempl.Integration.FiltersRenderTest do
  @moduledoc """
  End-to-end tests for formatting filters through the full `Ootempl.render`
  pipeline: built-ins, application config, per-call `:filters`, filters inside
  repeating block tables, default formatting of date values, and run-splitting.
  """

  use ExUnit.Case, async: false

  alias Ootempl.FixtureHelper

  @template "test/fixtures/filters_template.docx"
  @output "test/fixtures/filters_output.docx"

  setup do
    on_exit(fn ->
      File.rm(@template)
      File.rm(@output)
    end)

    :ok
  end

  defp render_body(body, data, opts \\ []) do
    FixtureHelper.create_docx_with_body(@template, body)
    assert :ok = Ootempl.render(@template, data, @output, opts)
    {:ok, xml} = OotemplTestHelpers.extract_file_for_test(@output, "word/document.xml")
    xml
  end

  describe "built-in filters end-to-end" do
    test "currency filter formats a value in the document body" do
      body = ~S(<w:p><w:r><w:t>Total: {{amount | currency: "USD"}}</w:t></w:r></w:p>)
      xml = render_body(body, %{"amount" => 1234.5})

      assert xml =~ "Total: $1,234.50"
      refute xml =~ "{{amount"
    end

    test "date filter formats a Date value" do
      body = ~S(<w:p><w:r><w:t>Dated {{d | date: "%d %B %Y"}}</w:t></w:r></w:p>)
      xml = render_body(body, %{"d" => ~D[2026-06-15]})

      assert xml =~ "Dated 15 June 2026"
    end
  end

  describe "default formatting (no filter)" do
    test "a Date value renders with the ISO default when no filter is given" do
      body = ~S(<w:p><w:r><w:t>On {{d}}</w:t></w:r></w:p>)
      xml = render_body(body, %{"d" => ~D[2026-06-15]})

      assert xml =~ "On 2026-06-15"
    end

    test "a bare Date and a Date with the default date filter agree" do
      body =
        ~S(<w:p><w:r><w:t>{{d}} == {{d | date}}</w:t></w:r></w:p>)

      xml = render_body(body, %{"d" => ~D[2026-06-15]})
      assert xml =~ "2026-06-15 == 2026-06-15"
    end
  end

  describe "per-call :filters option" do
    test "a custom filter passed to render/4 is applied" do
      body = ~S(<w:p><w:r><w:t>{{name | shout}}</w:t></w:r></w:p>)
      filters = %{"shout" => fn v, _ -> {:ok, String.upcase("#{v}!")} end}

      xml = render_body(body, %{"name" => "ada"}, filters: filters)
      assert xml =~ "ADA!"
    end

    test "a per-call filter overrides a built-in" do
      body = ~S(<w:p><w:r><w:t>{{name | upcase}}</w:t></w:r></w:p>)
      filters = %{"upcase" => fn _v, _ -> {:ok, "OVERRIDDEN"} end}

      xml = render_body(body, %{"name" => "ada"}, filters: filters)
      assert xml =~ "OVERRIDDEN"
    end
  end

  describe "application config filters" do
    test "a filter registered in app config is applied during render" do
      Application.put_env(:ootempl, :filters, %{"shout" => fn v, _ -> {:ok, "#{v}!!"} end})
      on_exit(fn -> Application.delete_env(:ootempl, :filters) end)

      body = ~S(<w:p><w:r><w:t>{{name | shout}}</w:t></w:r></w:p>)
      xml = render_body(body, %{"name" => "hi"})

      assert xml =~ "hi!!"
    end
  end

  describe "filters inside repeating block tables" do
    test "filters are applied to placeholders within each generated row" do
      body = """
      <w:tbl>
        <w:tr><w:tc><w:p><w:r><w:t>{{#items}}</w:t></w:r></w:p></w:tc></w:tr>
        <w:tr>
          <w:tc><w:p><w:r><w:t>{{name | upcase}}</w:t></w:r></w:p></w:tc>
          <w:tc><w:p><w:r><w:t>{{price | currency: "USD"}}</w:t></w:r></w:p></w:tc>
        </w:tr>
        <w:tr><w:tc><w:p><w:r><w:t>{{/items}}</w:t></w:r></w:p></w:tc></w:tr>
      </w:tbl>
      """

      data = %{
        "items" => [
          %{"name" => "apple", "price" => 1.5},
          %{"name" => "pear", "price" => 1234.0}
        ]
      }

      xml = render_body(body, data)

      assert xml =~ "APPLE"
      assert xml =~ "$1.50"
      assert xml =~ "PEAR"
      assert xml =~ "$1,234.00"
    end

    test "a per-call :filters override reaches placeholders inside table rows" do
      body = """
      <w:tbl>
        <w:tr><w:tc><w:p><w:r><w:t>{{#items}}</w:t></w:r></w:p></w:tc></w:tr>
        <w:tr><w:tc><w:p><w:r><w:t>{{name | badge}}</w:t></w:r></w:p></w:tc></w:tr>
        <w:tr><w:tc><w:p><w:r><w:t>{{/items}}</w:t></w:r></w:p></w:tc></w:tr>
      </w:tbl>
      """

      data = %{"items" => [%{"name" => "a"}, %{"name" => "b"}]}
      filters = %{"badge" => fn v, _ -> {:ok, "[#{v}]"} end}

      xml = render_body(body, data, filters: filters)

      assert xml =~ "[a]"
      assert xml =~ "[b]"
    end
  end

  describe "filter errors during render" do
    test "a filter error is surfaced as a PlaceholderError" do
      FixtureHelper.create_docx_with_body(
        @template,
        ~S(<w:p><w:r><w:t>{{d | date}}</w:t></w:r></w:p>)
      )

      assert {:error, %Ootempl.PlaceholderError{placeholders: [%{reason: reason}]}} =
               Ootempl.render(@template, %{"d" => 42}, @output)

      assert reason == {:filter_error, "date", :not_a_date}
    end
  end

  describe "XML escaping of filter output" do
    test "special characters produced by a filter are XML-escaped in the output" do
      # A filter that emits a raw ampersand; the pipeline must escape it so the
      # output stays valid XML. Filter output goes through the same escaping as
      # substituted data values, which this codebase double-escapes
      # (& -> &amp; -> &amp;amp;); see RenderTest for the documented behavior.
      body = ~S(<w:p><w:r><w:t>{{x | amp}}</w:t></w:r></w:p>)
      filters = %{"amp" => fn _v, _ -> {:ok, "A & B"} end}

      xml = render_body(body, %{"x" => "z"}, filters: filters)

      assert {:ok, _parsed} = Ootempl.Xml.parse(xml)
      assert xml =~ "A &amp;amp; B"
    end
  end
end
