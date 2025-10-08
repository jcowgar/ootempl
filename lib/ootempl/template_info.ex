defmodule Ootempl.TemplateInfo do
  @moduledoc """
  Information about a template's structure and requirements.

  This struct is returned by `Ootempl.inspect/1` and contains
  detailed information about placeholders, conditionals, validation errors,
  and required data keys found in a template.

  ## Fields

  - `:valid?` - Whether the template passed all validation checks
  - `:placeholders` - List of all placeholder information found in the template
  - `:conditionals` - List of all conditional markers found in the template
  - `:required_keys` - Top-level data keys required by the template
  - `:errors` - List of syntax or structural errors found during inspection

  ## Examples

      # Inspect a template
      {:ok, info} = Ootempl.inspect("contract.docx")

      # Check if valid
      if info.valid? do
        IO.puts("Template is valid")
      else
        IO.puts("Errors found: \#{length(info.errors)}")
      end

      # List required data keys
      IO.puts("Required keys: \#{Enum.join(info.required_keys, ", ")}")

      # List placeholders
      Enum.each(info.placeholders, fn ph ->
        IO.puts("Placeholder: \#{ph.original}")
        IO.puts("  Path: \#{Enum.join(ph.path, ".")}")
        IO.puts("  Locations: \#{inspect(ph.locations)}")
      end)

      # List conditionals
      Enum.each(info.conditionals, fn cond ->
        IO.puts("Conditional: \#{cond.condition}")
        IO.puts("  Path: \#{Enum.join(cond.path, ".")}")
      end)
  """

  @type t :: %__MODULE__{
          valid?: boolean(),
          placeholders: [placeholder_info()],
          conditionals: [conditional_info()],
          required_keys: [String.t()],
          errors: [error_info()]
        }

  @type error_info :: %{
          type:
            :unclosed_conditional
            | :malformed_placeholder
            | :invalid_conditional_syntax
            | :nested_conditionals,
          message: String.t(),
          location: location() | nil
        }

  @type placeholder_info :: %{
          original: String.t(),
          path: [String.t()],
          locations: [location()]
        }

  @type conditional_info :: %{
          condition: String.t(),
          path: [String.t()],
          locations: [location()]
        }

  @type location ::
          :document_body
          | :header1
          | :header2
          | :header3
          | :footer1
          | :footer2
          | :footer3
          | :footnotes
          | :endnotes
          | :properties

  defstruct valid?: true,
            placeholders: [],
            conditionals: [],
            required_keys: [],
            errors: []
end
