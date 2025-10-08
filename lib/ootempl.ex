defmodule Ootempl do
  @moduledoc """
  Office document templating library for Elixir.

  Ootempl enables programmatic manipulation of Microsoft Word documents (.docx)
  by replacing placeholders with dynamic content to generate customized documents
  from templates.

  ## Features

  - Load and parse .docx templates
  - Replace `@variable@` placeholders with dynamic content
  - Support nested data access with dot notation (`@customer.name@`)
  - Conditional sections with `@if:condition@...@endif@` syntax
  - Dynamic table row generation from list data
  - Multi-row table templates for complex layouts
  - Replace placeholder images with dynamic content (PNG, JPEG, GIF)
  - Automatic image dimension scaling with aspect ratio preservation
  - Case-insensitive placeholder matching
  - Process headers, footers, footnotes, and endnotes
  - Replace placeholders in document properties (title, author, company)
  - Preserve Word formatting (bold, italic, fonts, table borders, shading)
  - Generate valid .docx output files
  - Comprehensive validation and error handling

  ## Basic Usage

  ### Simple Variable Replacement

  ```elixir
  # Render a template with placeholder replacement
  data = %{
    "name" => "John Doe",
    "customer" => %{"email" => "john@example.com"},
    "total" => 99.99
  }
  Ootempl.render("template.docx", data, "output.docx")
  #=> :ok
  ```

  ### Struct Support

  Elixir structs work seamlessly with `render/3`. You can pass structs directly
  without converting them to maps first. Struct fields (atoms) are matched
  case-insensitively to placeholders.

  ```elixir
  defmodule Customer do
    defstruct [:name, :email, :address]
  end

  defmodule Address do
    defstruct [:street, :city, :state, :zip]
  end

  # Use structs directly in your data
  customer = %Customer{
    name: "John Doe",
    email: "john@example.com",
    address: %Address{
      city: "Boston",
      state: "MA",
      zip: "02101"
    }
  }

  data = %{
    "order_id" => "ORD-12345",
    "customer" => customer
  }

  # Template can reference struct fields:
  # - @customer.name@ → "John Doe"
  # - @customer.email@ → "john@example.com"
  # - @customer.address.city@ → "Boston"

  Ootempl.render("invoice_template.docx", data, "invoice.docx")
  #=> :ok
  ```

  Struct features:
  - **Nested structs**: Access fields multiple levels deep
  - **Case-insensitive**: `@customer.Name@` matches `:name` field
  - **Mixed data**: Combine structs and maps in the same data structure
  - **Lists of structs**: Use structs in table templates

  ### Table Templates

  Table templates automatically duplicate rows based on list data. Template rows are
  identified by placeholders that reference list items.

  ```elixir
  # Simple table template
  data = %{
    "title" => "Claims Report",
    "claims" => [
      %{"id" => 5565, "amount" => 100.50},
      %{"id" => 5566, "amount" => 250.00}
    ],
    "total" => 350.50
  }
  Ootempl.render("invoice_template.docx", data, "invoice.docx")
  #=> :ok
  ```

  Template structure in Word document:
  ```
  | Claim ID       | Amount           |  ← Header (no list placeholders)
  | @claims.id@    | @claims.amount@  |  ← Template row (references "claims" list)
  | Total          | @total@          |  ← Footer (single value)
  ```

  Generated output:
  ```
  | Claim ID  | Amount  |
  | 5565      | 100.50  |
  | 5566      | 250.00  |
  | Total     | 350.50  |
  ```

  Multi-row templates are supported for complex table layouts:
  ```elixir
  data = %{
    "orders" => [
      %{"id" => 100, "product" => "Widget", "qty" => 5, "price" => 10.00},
      %{"id" => 101, "product" => "Gadget", "qty" => 3, "price" => 25.00}
    ]
  }
  ```

  Template with two rows per order:
  ```
  | Order @orders.id@              |  ← Row 1 of template
  | @orders.qty@x @orders.product@ @ $@orders.price@ each |  ← Row 2 of template
  ```

  Generated output duplicates both rows for each order:
  ```
  | Order 100           |
  | 5x Widget @ $10.00 each |
  | Order 101           |
  | 3x Gadget @ $25.00 each |
  ```

  ### Conditional Sections

  Control which sections of your document appear based on data conditions using
  `@if:condition@...@endif@` markers. Sections are shown when the condition is
  truthy and hidden when falsy.

  ```elixir
  # Template structure:
  # Standard content here.
  #
  # @if:show_disclaimer@
  # DISCLAIMER: This is a legal disclaimer that appears
  # only when show_disclaimer is true.
  # @endif@
  #
  # @if:include_pricing@
  # Pricing: $100/month
  # @endif@

  data = %{
    "show_disclaimer" => true,
    "include_pricing" => false
  }
  Ootempl.render("contract_template.docx", data, "contract.docx")
  #=> :ok
  # Generated document includes disclaimer section, excludes pricing section
  ```

  **If/Else Support:**

  Use `@else@` markers to show alternative content when a condition is false:

  ```elixir
  # Template structure:
  # Dear Customer,
  #
  # @if:is_premium@
  # Thank you for being a premium member! You get 20% off.
  # @else@
  # Become a premium member today for 20% off all purchases.
  # @endif@
  #
  # Thank you!

  data_premium = %{"is_premium" => true}
  Ootempl.render("letter.docx", data_premium, "premium_letter.docx")
  # Output: "Thank you for being a premium member! You get 20% off."

  data_standard = %{"is_premium" => false}
  Ootempl.render("letter.docx", data_standard, "standard_letter.docx")
  # Output: "Become a premium member today for 20% off all purchases."
  ```

  **Truthiness rules:**
  - **Truthy**: non-nil, non-false, non-empty string, non-zero number
  - **Falsy**: `nil`, `false`, `""` (empty string), `0`, `0.0`

  **Conditional features:**
  - Case-insensitive markers: `@IF:name@`, `@if:NAME@`, `@ELSE@` all work
  - Nested data paths: `@if:customer.active@`
  - Optional `@else@` for alternative content
  - Multi-paragraph sections supported
  - Sections can contain tables, images, lists, etc.

  ### Document Properties

  Placeholders in document metadata (title, author, company) are automatically replaced.
  Use this feature to populate document properties from your data.

  ```elixir
  # Template has placeholders in File > Properties:
  # - Title: @document_title@
  # - Author: @author@
  # - Company: @company_name@

  data = %{
    "document_title" => "Q4 Financial Report",
    "author" => "Jane Smith",
    "company_name" => "Acme Corporation"
  }
  Ootempl.render("report_template.docx", data, "Q4_report.docx")
  #=> :ok
  # Generated document has Title, Author, and Company fields populated
  ```

  Supported property fields:
  - **Core properties**: `dc:title`, `dc:subject`, `dc:description`, `dc:creator`
  - **App properties**: `Company`, `Manager`

  ### Headers, Footers, Footnotes, and Endnotes

  Placeholders in headers, footers, footnotes, and endnotes are processed just like
  the main document body:

  ```elixir
  # Template has:
  # - Header with: @company_name@ - @document_title@
  # - Footer with: Page @page@ of @total_pages@
  # - Footnote with: @footnote_citation@

  data = %{
    "company_name" => "Acme Corp",
    "document_title" => "Annual Report",
    "footnote_citation" => "Source: Annual Review 2025"
  }
  Ootempl.render("template.docx", data, "output.docx")
  ```

  ### Image Replacement

  Replace placeholder images in templates with dynamic images from your data. Use the
  alt text field in Word to mark placeholder images with `@image:name@` markers.

  **Preparing templates in Word:**

  1. Insert a placeholder image (any PNG, JPEG, or GIF)
  2. Right-click the image → "View Alt Text" (or "Edit Alt Text")
  3. Set the alt text to `@image:placeholder_name@` (e.g., `@image:company_logo@`)
  4. Save the template

  **Data structure:**

  Provide image file paths in your data map using the placeholder name as the key:

  ```elixir
  data = %{
    "company_logo" => "/path/to/logo.png",
    "employee_photo" => "/path/to/photo.jpg",
    "signature" => "/path/to/signature.gif"
  }
  Ootempl.render("template.docx", data, "output.docx")
  #=> :ok
  ```

  **Image format support:**

  - **PNG** - Portable Network Graphics (`.png`)
  - **JPEG** - Joint Photographic Experts Group (`.jpg`, `.jpeg`)
  - **GIF** - Graphics Interchange Format (`.gif`)

  **Automatic dimension scaling:**

  Images are automatically scaled to fit the placeholder dimensions while preserving
  aspect ratio. The library calculates the minimum scale factor needed to fit the
  image within the template bounds:

  ```elixir
  # Template has 200x100 EMU placeholder
  # Image is 800x600 pixels → scaled by 0.25x to fit
  # Image is 150x75 pixels → scaled by 1.33x to fill space

  data = %{"logo" => "large_image.png"}
  Ootempl.render("template.docx", data, "output.docx")
  # Image automatically scaled to fit placeholder bounds
  ```

  **Multiple images:**

  Templates can contain multiple placeholder images, each with a unique marker:

  ```elixir
  # Template contains three images:
  # - Header logo with alt text: @image:company_logo@
  # - Employee photo with alt text: @image:employee_photo@
  # - Footer signature with alt text: @image:signature@

  data = %{
    "company_logo" => "assets/logo.png",
    "employee_photo" => "photos/john_doe.jpg",
    "signature" => "signatures/ceo.gif"
  }
  Ootempl.render("contract_template.docx", data, "contract.docx")
  #=> :ok
  # All three images replaced with dynamic content
  ```

  **Error handling:**

  Image replacement returns errors for missing data or invalid files:

  ```elixir
  # Missing image key in data
  data = %{"name" => "John"}
  Ootempl.render("template.docx", data, "output.docx")
  #=> {:error, %Ootempl.ImageError{
  #     message: "Image placeholder '@image:logo@' has no corresponding data key 'logo'",
  #     placeholder_name: "logo",
  #     image_path: nil,
  #     reason: :image_not_found_in_data
  #   }}

  # Image file doesn't exist
  data = %{"logo" => "nonexistent.png"}
  Ootempl.render("template.docx", data, "output.docx")
  #=> {:error, %Ootempl.ImageError{
  #     message: "Image file not found for placeholder 'logo': nonexistent.png",
  #     placeholder_name: "logo",
  #     image_path: "nonexistent.png",
  #     reason: :file_not_found
  #   }}

  # Unsupported format
  data = %{"logo" => "document.pdf"}
  Ootempl.render("template.docx", data, "output.docx")
  #=> {:error, %Ootempl.ImageError{
  #     message: "Unsupported image format for placeholder 'logo': document.pdf (format: .pdf, only PNG, JPEG, GIF supported)",
  #     placeholder_name: "logo",
  #     image_path: "document.pdf",
  #     reason: :unsupported_format
  #   }}
  ```

  ## Architecture

  The library is organized into several modules:

  - `Ootempl.Archive` - ZIP archive operations for .docx files
  - `Ootempl.Xml` - XML parsing and serialization using :xmerl
  - `Ootempl.Xml.Normalizer` - XML normalization for fragmented placeholders
  - `Ootempl.Placeholder` - Placeholder detection and parsing
  - `Ootempl.DataAccess` - Nested data access with case-insensitive matching
  - `Ootempl.Conditional` - Conditional marker detection, evaluation, and section processing
  - `Ootempl.Replacement` - Placeholder replacement in XML with formatting preservation
  - `Ootempl.Table` - Table structure detection, template row identification, and duplication
  - `Ootempl.Validator` - Document validation and error handling

  ## Error Handling

  The main `render/3` function returns:
  - `:ok` on success (document generated successfully)
  - `{:error, %PlaceholderError{}}` when placeholders cannot be resolved
  - `{:error, exception}` on structural failures

  Specific error types:
  - `Ootempl.PlaceholderError` - One or more placeholders cannot be resolved
  - `Ootempl.ValidationError` - File validation failures
  - `Ootempl.InvalidArchiveError` - Invalid ZIP structure
  - `Ootempl.MissingFileError` - Required files missing
  - `Ootempl.MalformedXMLError` - XML parsing failures
  """

  alias Ootempl.Archive
  alias Ootempl.Conditional
  alias Ootempl.Image
  alias Ootempl.Relationships
  alias Ootempl.Replacement
  alias Ootempl.Table
  alias Ootempl.Template
  alias Ootempl.Validator
  alias Ootempl.Xml
  alias Ootempl.Xml.Normalizer

  @doc """
  Loads and pre-processes a .docx template for batch rendering.

  This function reads a .docx template file once, parses all XML structures,
  normalizes them, and returns a `%Template{}` struct that can be reused for
  multiple render operations. This provides significant performance benefits
  when generating multiple documents from the same template.

  ## Performance

  Loading a template eliminates ~40% of rendering time for batch operations:
  - File I/O: ~20% savings
  - XML parsing: ~18% savings
  - Normalization: ~0.2% savings

  For example, generating 100 invoices:
  - Without pre-loading: ~10ms × 100 = 1000ms
  - With pre-loading: ~60ms (load) + ~6ms × 100 = 660ms (34% faster)

  ## Parameters

  - `template_path` - Path to the .docx template file

  ## Returns

  - `{:ok, %Template{}}` on success
  - `{:error, reason}` on failure (invalid file, corrupt ZIP, etc.)

  ## Examples

      # Load template once
      {:ok, template} = Ootempl.load("invoice_template.docx")

      # Render multiple documents (reusing parsed template)
      customers
      |> Enum.each(fn customer ->
        data = %{"name" => customer.name, "total" => customer.balance}
        Ootempl.render(template, data, "invoice_\#{customer.id}.docx")
      end)

  ## Error Cases

  Same validation errors as `render/3`:
  - Template file does not exist
  - Template is not a valid .docx file
  - Template has invalid XML structure
  """
  @spec load(Path.t()) :: {:ok, Template.t()} | {:error, term()}
  def load(template_path) do
    with :ok <- Validator.validate_docx(template_path),
         {:ok, temp_dir} <- Archive.extract(template_path),
         {:ok, template} <- load_and_parse_template(temp_dir, template_path),
         :ok <- Archive.cleanup(temp_dir) do
      {:ok, template}
    else
      {:error, _reason} = error -> error
    end
  end

  @doc """
  Renders a .docx template with data to generate an output document.

  This function accepts either a template file path (String) or a pre-loaded
  `%Template{}` struct. Using a pre-loaded template is significantly faster
  for batch operations.

  Replaces `@variable@` placeholders in the template with values from the data map,
  supporting nested data access with dot notation (e.g., `@customer.name@`).
  Case-insensitive matching ensures `@Name@`, `@name@`, and `@NAME@` all match
  the same data key.

  ## Parameters

  - `template` - Either:
    - A file path (String) to a .docx template - loads, parses, and renders in one call
    - A `%Template{}` struct from `Ootempl.load/1` - skips loading/parsing (fast)
  - `data` - Map of data for placeholder replacement (string keys)
  - `output_path` - Path where the generated .docx file should be saved

  ## Returns

  - `:ok` on success
  - `{:error, %PlaceholderError{}}` when placeholders cannot be resolved
  - `{:error, exception}` on structural failures (invalid file, corrupt ZIP, etc.)

  ## Examples

      ### Single Document (Convenience API)

      data = %{
        "name" => "John Doe",
        "customer" => %{"email" => "john@example.com"},
        "total" => 99.99
      }
      Ootempl.render("template.docx", data, "output.docx")
      #=> :ok

      ### Batch Processing (Optimized API)

      # Load template once
      {:ok, template} = Ootempl.load("invoice_template.docx")

      # Render many documents (40% faster)
      Enum.each(customers, fn customer ->
        data = %{"name" => customer.name, "total" => customer.balance}
        Ootempl.render(template, data, "invoice_\#{customer.id}.docx")
      end)

      ### Error Handling

      # Missing placeholders (collects all errors)
      Ootempl.render("template.docx", %{}, "output.docx")
      #=> {:error, %Ootempl.PlaceholderError{
      #     message: "2 placeholders could not be resolved (first: @name@)",
      #     placeholders: [
      #       %{placeholder: "@name@", reason: {:path_not_found, ["name"]}},
      #       %{placeholder: "@customer.email@", reason: {:path_not_found, ["customer", "email"]}}
      #     ]
      #   }}

      # Structural errors
      Ootempl.render("missing.docx", %{}, "out.docx")
      #=> {:error, %Ootempl.ValidationError{reason: :file_not_found}}

  ## Error Cases

  ### Structural Errors (fail-fast)
  - Template file does not exist
  - Template is not a valid .docx file
  - Template and output are the same file
  - Output directory does not exist or is not writable
  - Insufficient disk space
  - Template file is locked/in use

  ### Placeholder Errors (collected and returned together)
  - Placeholder not found in data map
  - Invalid nested path
  - Nil values in data
  - Unsupported data types (maps, lists as values)
  """
  @spec render(Path.t() | Template.t(), map() | struct(), Path.t()) :: :ok | {:error, term()}
  def render(template, data, output_path)

  # Pattern 1: Render from pre-loaded Template struct (optimized for batch processing)
  def render(%Template{} = template, data, output_path) do
    with :ok <- validate_output_path(output_path) do
      render_from_template(template, data, output_path)
    end
  end

  # Pattern 2: Render from file path (convenience API - loads template on each call)
  def render(template_path, data, output_path) when is_binary(template_path) do
    with :ok <- validate_paths(template_path, output_path),
         :ok <- Validator.validate_docx(template_path) do
      # Extract template and ensure cleanup happens regardless of success or failure
      case Archive.extract(template_path) do
        {:ok, temp_dir} ->
          # Process template and always cleanup temp directory, even on error
          result = process_template(temp_dir, data, output_path)
          cleanup_result = Archive.cleanup(temp_dir)

          # Return original result or cleanup error
          case {result, cleanup_result} do
            {:ok, :ok} -> :ok
            {:ok, {:error, _} = cleanup_error} -> cleanup_error
            {error, _} -> error
          end

        {:error, _reason} = error ->
          error
      end
    else
      {:error, _reason} = error -> error
    end
  end

  # Private functions

  @spec process_template(Path.t(), map(), Path.t()) :: :ok | {:error, term()}
  defp process_template(temp_dir, data, output_path) do
    with :ok <- process_single_xml_file(temp_dir, "word/document.xml", data),
         :ok <- process_header_footer_files(temp_dir, data),
         :ok <- process_footnote_endnote_files(temp_dir, data),
         :ok <- process_document_properties(temp_dir, data),
         {:ok, file_map} <- build_file_map(temp_dir) do
      Archive.create(file_map, output_path)
    end
  end

  # Processes a single XML file through the full replacement pipeline.
  #
  # Applies the complete processing pipeline to a single XML file:
  # - Load XML content
  # - Parse XML
  # - Normalize (collapse fragmented placeholders)
  # - Process conditionals (FIRST - before tables and variables)
  # - Process tables (if any)
  # - Replace placeholders
  # - Serialize back to XML
  # - Save to disk
  @spec process_single_xml_file(Path.t(), String.t(), map()) :: :ok | {:error, term()}
  defp process_single_xml_file(temp_dir, relative_path, data) do
    file_path = Path.join(temp_dir, relative_path)

    with {:ok, xml_content} <- File.read(file_path),
         {:ok, xml_doc} <- Xml.parse(xml_content),
         normalized_doc = Normalizer.normalize(xml_doc),
         {:ok, conditional_processed_doc} <- process_conditionals(normalized_doc, data),
         {:ok, table_processed_doc} <- process_tables(conditional_processed_doc, data),
         {:ok, replaced_doc} <- Replacement.replace_in_document(table_processed_doc, data),
         {:ok, image_processed_doc} <- process_images(replaced_doc, data, temp_dir),
         {:ok, modified_xml} <- Xml.serialize(image_processed_doc),
         :ok <- File.write(file_path, modified_xml) do
      :ok
    else
      # PlaceholderError should be returned directly without wrapping
      {:error, %Ootempl.PlaceholderError{} = error} -> {:error, error}
      # Other errors are wrapped with context
      {:error, reason} -> {:error, {:file_processing_failed, relative_path, reason}}
    end
  end

  # Discovers and processes all header and footer XML files in the document.
  #
  # Finds all `word/header*.xml` and `word/footer*.xml` files using Path.wildcard
  # and applies the same processing pipeline used for the main document body.
  #
  # Missing header/footer files are OK (not all documents have them).
  @spec process_header_footer_files(Path.t(), map()) :: :ok | {:error, term()}
  defp process_header_footer_files(temp_dir, data) do
    header_files = Path.wildcard(Path.join(temp_dir, "word/header*.xml"))
    footer_files = Path.wildcard(Path.join(temp_dir, "word/footer*.xml"))

    all_files = header_files ++ footer_files

    # Convert absolute paths to relative paths
    relative_files =
      Enum.map(all_files, fn file_path ->
        Path.relative_to(file_path, temp_dir)
      end)

    # Process each file
    Enum.reduce_while(relative_files, :ok, fn relative_path, _acc ->
      case process_single_xml_file(temp_dir, relative_path, data) do
        :ok -> {:cont, :ok}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  # Processes footnotes and endnotes XML files if they exist.
  #
  # Finds `word/footnotes.xml` and `word/endnotes.xml` files and applies
  # the same processing pipeline used for the main document body.
  # These files use the same w:p/w:r/w:t XML structure as document.xml.
  #
  # Missing files are OK (not all documents have footnotes or endnotes).
  @spec process_footnote_endnote_files(Path.t(), map()) :: :ok | {:error, term()}
  defp process_footnote_endnote_files(temp_dir, data) do
    ["word/footnotes.xml", "word/endnotes.xml"]
    |> Enum.filter(&File.exists?(Path.join(temp_dir, &1)))
    |> Enum.reduce_while(:ok, fn relative_path, _acc ->
      case process_single_xml_file(temp_dir, relative_path, data) do
        :ok -> {:cont, :ok}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  # Processes document property files for placeholder replacement.
  #
  # Handles `docProps/core.xml` (title, subject, description, creator) and
  # `docProps/app.xml` (company, manager) files. These files use simpler XML
  # structures with direct text content rather than Word's paragraph/run structure.
  #
  # Missing property files are OK (not all documents have all properties set).
  @spec process_document_properties(Path.t(), map()) :: :ok | {:error, term()}
  defp process_document_properties(temp_dir, data) do
    ["docProps/core.xml", "docProps/app.xml"]
    |> Enum.filter(&File.exists?(Path.join(temp_dir, &1)))
    |> Enum.reduce_while(:ok, fn relative_path, _acc ->
      case process_property_file(temp_dir, relative_path, data) do
        :ok -> {:cont, :ok}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  # Processes a document property XML file using simple text replacement.
  #
  # Property files have simpler XML structures with direct text content
  # (e.g., `<dc:title>@title@</dc:title>`) rather than the complex
  # w:p/w:r/w:t structure used in the main document. This function uses
  # the full XML processing pipeline to ensure proper handling.
  @spec process_property_file(Path.t(), String.t(), map()) :: :ok | {:error, term()}
  defp process_property_file(temp_dir, relative_path, data) do
    file_path = Path.join(temp_dir, relative_path)

    with {:ok, xml_content} <- File.read(file_path),
         {:ok, xml_doc} <- Xml.parse(xml_content),
         normalized_doc = Normalizer.normalize(xml_doc),
         {:ok, replaced_doc} <- Replacement.replace_in_document(normalized_doc, data),
         {:ok, modified_xml} <- Xml.serialize(replaced_doc),
         :ok <- File.write(file_path, modified_xml) do
      :ok
    else
      {:error, %Ootempl.PlaceholderError{} = error} -> {:error, error}
      {:error, reason} -> {:error, {:property_file_processing_failed, relative_path, reason}}
    end
  end

  # Processes conditional sections in an XML document.
  #
  # Detects all `@if:condition@...@endif@` markers, evaluates conditions,
  # and either removes sections (when false) or removes markers (when true).
  #
  # This must run BEFORE variable replacement to ensure removed sections
  # don't get processed.
  @spec process_conditionals(Xml.xml_element(), map()) :: {:ok, Xml.xml_element()} | {:error, term()}
  defp process_conditionals(xml_doc, data) do
    # Extract all text to detect conditionals
    text = extract_all_text_from_doc(xml_doc)

    # Detect all conditional markers
    conditionals = Conditional.detect_conditionals(text)

    # If no conditionals, return document unchanged
    if Enum.empty?(conditionals) do
      {:ok, xml_doc}
    else
      # Validate marker pairs
      case Conditional.validate_pairs(conditionals) do
        :ok ->
          # Process all conditional pairs
          process_all_conditionals(xml_doc, conditionals, data)

        {:error, reason} ->
          {:error, {:conditional_validation_failed, reason}}
      end
    end
  end

  # Processes all conditional pairs in the document
  # Re-detects conditionals after each processing step to avoid stale references
  @spec process_all_conditionals(Xml.xml_element(), [Conditional.conditional()], map()) ::
          {:ok, Xml.xml_element()} | {:error, term()}
  defp process_all_conditionals(xml_doc, _conditionals, data) do
    # Process conditionals one at a time, re-detecting after each
    process_conditionals_iteratively(xml_doc, data)
  end

  # Iteratively process conditionals, re-detecting after each one
  @spec process_conditionals_iteratively(Xml.xml_element(), map()) ::
          {:ok, Xml.xml_element()} | {:error, term()}
  defp process_conditionals_iteratively(xml_doc, data) do
    # Extract text and detect conditionals
    text = extract_all_text_from_doc(xml_doc)
    conditionals = Conditional.detect_conditionals(text)

    # If no conditionals remain, we're done
    if Enum.empty?(conditionals) do
      {:ok, xml_doc}
    else
      process_detected_conditionals(xml_doc, conditionals, data)
    end
  end

  # Processes detected conditionals after validation
  @spec process_detected_conditionals(Xml.xml_element(), [Conditional.conditional()], map()) ::
          {:ok, Xml.xml_element()} | {:error, term()}
  defp process_detected_conditionals(xml_doc, conditionals, data) do
    # Validate pairs
    case Conditional.validate_pairs(conditionals) do
      :ok ->
        process_first_conditional_pair(xml_doc, conditionals, data)

      {:error, reason} ->
        {:error, {:conditional_validation_failed, reason}}
    end
  end

  # Processes the first conditional pair and recurses
  @spec process_first_conditional_pair(Xml.xml_element(), [Conditional.conditional()], map()) ::
          {:ok, Xml.xml_element()} | {:error, term()}
  defp process_first_conditional_pair(xml_doc, conditionals, data) do
    pairs = group_conditional_pairs(conditionals)

    case pairs do
      [] ->
        {:ok, xml_doc}

      [first_pair | _rest] ->
        # Process the first conditional pair
        case process_single_conditional(xml_doc, first_pair, data) do
          {:ok, modified_doc} ->
            # Re-detect and process remaining conditionals
            process_conditionals_iteratively(modified_doc, data)

          {:error, _reason} = error ->
            error
        end
    end
  end

  # Groups conditional markers into if/else/endif triplets (or if/endif pairs if no else)
  @spec group_conditional_pairs([Conditional.conditional()]) ::
          [%{if: Conditional.conditional(), else: Conditional.conditional() | nil, endif: Conditional.conditional()}]
  defp group_conditional_pairs(conditionals) do
    do_group_pairs(conditionals, [], [])
  end

  @spec do_group_pairs(
          [Conditional.conditional()],
          [{Conditional.conditional(), Conditional.conditional() | nil}],
          [%{if: Conditional.conditional(), else: Conditional.conditional() | nil, endif: Conditional.conditional()}]
        ) :: [%{if: Conditional.conditional(), else: Conditional.conditional() | nil, endif: Conditional.conditional()}]
  defp do_group_pairs([], _stack, pairs), do: Enum.reverse(pairs)

  defp do_group_pairs([%{type: :if} = marker | rest], stack, pairs) do
    # Push if marker with no else marker yet
    do_group_pairs(rest, [{marker, nil} | stack], pairs)
  end

  defp do_group_pairs([%{type: :else} = marker | rest], [{if_marker, _} | stack_rest], pairs) do
    # Update the top of stack to include the else marker
    do_group_pairs(rest, [{if_marker, marker} | stack_rest], pairs)
  end

  defp do_group_pairs([%{type: :endif} = marker | rest], [{if_marker, else_marker} | stack], pairs) do
    pair = %{if: if_marker, else: else_marker, endif: marker}
    do_group_pairs(rest, stack, [pair | pairs])
  end

  # Processes a single conditional (if/else/endif or if/endif)
  @spec process_single_conditional(
          Xml.xml_element(),
          %{if: Conditional.conditional(), else: Conditional.conditional() | nil, endif: Conditional.conditional()},
          map()
        ) :: {:ok, Xml.xml_element()} | {:error, term()}
  defp process_single_conditional(xml_doc, %{if: if_marker, else: else_marker, endif: endif_marker} = pair, data) do
    # Evaluate the condition
    case Conditional.evaluate_condition(if_marker.path, data) do
      {:ok, true} ->
        # Condition is true: keep if section, remove else section (if present)
        remove_conditional_markers_and_else_section(xml_doc, pair)

      {:ok, false} ->
        # Condition is false: remove if section, keep else section (if present)
        remove_if_section_keep_else(xml_doc, if_marker, else_marker, endif_marker)

      {:error, reason} ->
        {:error, {:conditional_evaluation_failed, if_marker.condition, reason}}
    end
  end

  # Removes conditional markers and else section (when condition is true)
  @spec remove_conditional_markers_and_else_section(
          Xml.xml_element(),
          %{if: Conditional.conditional(), else: Conditional.conditional() | nil, endif: Conditional.conditional()}
        ) :: {:ok, Xml.xml_element()} | {:error, term()}
  defp remove_conditional_markers_and_else_section(xml_doc, %{if: if_marker, else: nil, endif: _endif_marker}) do
    # No else section: just remove the if and endif markers
    if_marker_text = "@if:#{if_marker.condition}@"
    endif_marker_text = "@endif@"

    case Conditional.find_section_boundaries(xml_doc, if_marker_text, endif_marker_text) do
      {:ok, {start_para, end_para}} ->
        modified_doc = Xml.remove_nodes(xml_doc, [start_para, end_para])
        {:ok, modified_doc}

      {:error, reason} ->
        {:error, {:marker_removal_failed, reason}}
    end
  end

  defp remove_conditional_markers_and_else_section(
         xml_doc,
         %{if: if_marker, else: _else_marker, endif: _endif_marker}
       ) do
    # Has else section: remove if marker, remove entire else section through endif
    if_marker_text = "@if:#{if_marker.condition}@"
    else_marker_text = "@else@"
    endif_marker_text = "@endif@"

    with {:ok, if_para} <- find_paragraph(xml_doc, if_marker_text),
         {:ok, {else_para, endif_para}} <-
           Conditional.find_section_boundaries(xml_doc, else_marker_text, endif_marker_text),
         {:ok, nodes_to_remove} <- collect_else_section_nodes(xml_doc, else_para, endif_para) do
      # Remove if marker paragraph and all nodes from else through endif
      modified_doc = Xml.remove_nodes(xml_doc, [if_para | nodes_to_remove])
      {:ok, modified_doc}
    else
      {:error, reason} -> {:error, {:marker_removal_failed, reason}}
    end
  end

  # Removes if section and keeps else section (when condition is false)
  @spec remove_if_section_keep_else(
          Xml.xml_element(),
          Conditional.conditional(),
          Conditional.conditional() | nil,
          Conditional.conditional()
        ) :: {:ok, Xml.xml_element()} | {:error, term()}
  defp remove_if_section_keep_else(xml_doc, if_marker, nil, _endif_marker) do
    # No else section: remove entire if/endif section
    if_marker_text = "@if:#{if_marker.condition}@"
    endif_marker_text = "@endif@"

    case Conditional.find_section_boundaries(xml_doc, if_marker_text, endif_marker_text) do
      {:ok, {start_para, end_para}} ->
        body_element = find_body_element(xml_doc)

        case Conditional.collect_section_nodes(body_element, start_para, end_para) do
          {:ok, nodes_to_remove} ->
            modified_doc = Xml.remove_nodes(xml_doc, nodes_to_remove)
            {:ok, modified_doc}

          {:error, reason} ->
            {:error, {:section_boundary_error, reason}}
        end

      {:error, reason} ->
        {:error, {:section_boundary_not_found, if_marker.condition, reason}}
    end
  end

  defp remove_if_section_keep_else(xml_doc, if_marker, _else_marker, _endif_marker) do
    # Has else section: remove if section through else, remove else and endif markers
    if_marker_text = "@if:#{if_marker.condition}@"
    else_marker_text = "@else@"
    endif_marker_text = "@endif@"

    with {:ok, {if_para, else_para}} <- Conditional.find_section_boundaries(xml_doc, if_marker_text, else_marker_text),
         {:ok, endif_para} <- find_paragraph(xml_doc, endif_marker_text),
         {:ok, if_section_nodes} <- collect_if_section_nodes(xml_doc, if_para, else_para) do
      # Remove if section (if through else) and endif marker
      modified_doc = Xml.remove_nodes(xml_doc, if_section_nodes ++ [endif_para])
      {:ok, modified_doc}
    else
      {:error, reason} -> {:error, {:section_boundary_not_found, if_marker.condition, reason}}
    end
  end

  # Finds a paragraph containing specific text
  @spec find_paragraph(Xml.xml_element(), String.t()) ::
          {:ok, Xml.xml_element()} | {:error, :not_found}
  defp find_paragraph(xml_doc, text) do
    import Xml

    case Enum.find(find_all_paragraphs(xml_doc), fn para ->
           paragraph_contains_text?(para, text)
         end) do
      nil -> {:error, :not_found}
      para -> {:ok, para}
    end
  end

  # Collects nodes from else paragraph through endif paragraph (inclusive)
  @spec collect_else_section_nodes(Xml.xml_element(), Xml.xml_element(), Xml.xml_element()) ::
          {:ok, [Xml.xml_node()]} | {:error, term()}
  defp collect_else_section_nodes(xml_doc, else_para, endif_para) do
    body_element = find_body_element(xml_doc)
    Conditional.collect_section_nodes(body_element, else_para, endif_para)
  end

  # Collects nodes from if paragraph through else paragraph (inclusive)
  @spec collect_if_section_nodes(Xml.xml_element(), Xml.xml_element(), Xml.xml_element()) ::
          {:ok, [Xml.xml_node()]} | {:error, term()}
  defp collect_if_section_nodes(xml_doc, if_para, else_para) do
    body_element = find_body_element(xml_doc)
    Conditional.collect_section_nodes(body_element, if_para, else_para)
  end

  # Helper to find all paragraphs in a document
  @spec find_all_paragraphs(Xml.xml_element()) :: [Xml.xml_element()]
  defp find_all_paragraphs(xml_element) do
    import Xml

    children = xmlElement(xml_element, :content)
    Enum.flat_map(children, &collect_paragraph_from_node/1)
  end

  @spec collect_paragraph_from_node(Xml.xml_node()) :: [Xml.xml_element()]
  defp collect_paragraph_from_node(node) do
    import Xml
    require Record

    cond do
      not Record.is_record(node, :xmlElement) -> []
      xmlElement(node, :name) == :"w:p" -> [node]
      true -> find_all_paragraphs(node)
    end
  end

  # Helper to check if paragraph contains text
  @spec paragraph_contains_text?(Xml.xml_element(), String.t()) :: boolean()
  defp paragraph_contains_text?(paragraph, text) do
    import Xml

    paragraph
    |> extract_text_from_element()
    |> String.contains?(text)
  end

  # Helper to extract text from an element
  @spec extract_text_from_element(Xml.xml_element()) :: String.t()
  defp extract_text_from_element(element) do
    import Xml

    require Record

    children = xmlElement(element, :content)

    Enum.map_join(children, fn node ->
      cond do
        Record.is_record(node, :xmlText) ->
          node |> xmlText(:value) |> List.to_string()

        Record.is_record(node, :xmlElement) ->
          extract_text_from_element(node)

        true ->
          ""
      end
    end)
  end

  # Finds the w:body element in the document
  @spec find_body_element(Xml.xml_element()) :: Xml.xml_element()
  defp find_body_element(xml_doc) do
    import Xml

    require Record

    children = xmlElement(xml_doc, :content)

    Enum.find(children, fn node ->
      Record.is_record(node, :xmlElement) and xmlElement(node, :name) == :"w:body"
    end)
  end

  # Extracts all text content from the document for conditional detection
  @spec extract_all_text_from_doc(Xml.xml_element()) :: String.t()
  defp extract_all_text_from_doc(element) do
    import Xml

    require Record

    children = xmlElement(element, :content)

    Enum.map_join(children, fn node ->
      cond do
        Record.is_record(node, :xmlText) ->
          node |> xmlText(:value) |> List.to_string()

        Record.is_record(node, :xmlElement) ->
          extract_all_text_from_doc(node)

        true ->
          ""
      end
    end)
  end

  @spec process_tables(Xml.xml_element(), map()) :: {:ok, Xml.xml_element()} | {:error, term()}
  defp process_tables(xml_doc, data) do
    # Find all tables in document
    tables = Table.find_tables(xml_doc)

    # Process each table and collect results
    case process_all_tables(tables, data, xml_doc) do
      {:ok, modified_doc} -> {:ok, modified_doc}
      {:error, _reason} = error -> error
    end
  end

  @spec process_all_tables([Xml.xml_element()], map(), Xml.xml_element()) ::
          {:ok, Xml.xml_element()} | {:error, term()}
  defp process_all_tables([], _data, xml_doc), do: {:ok, xml_doc}

  defp process_all_tables([table | rest_tables], data, xml_doc) do
    case process_single_table(table, data, xml_doc) do
      {:ok, modified_doc} -> process_all_tables(rest_tables, data, modified_doc)
      {:error, _reason} = error -> error
    end
  end

  @spec process_single_table(Xml.xml_element(), map(), Xml.xml_element()) ::
          {:ok, Xml.xml_element()} | {:error, term()}
  defp process_single_table(table, data, xml_doc) do
    rows = Table.extract_rows(table)

    # Group template rows
    case Table.group_template_rows(rows, data) do
      {:ok, row_analyses} ->
        # Find template row groups and duplicate
        process_row_groups(table, row_analyses, data, xml_doc)

      {:error, {:multiple_lists, _row}} = error ->
        error
    end
  end

  @spec process_row_groups(Xml.xml_element(), [Table.row_analysis()], map(), Xml.xml_element()) ::
          {:ok, Xml.xml_element()} | {:error, term()}
  defp process_row_groups(table, row_analyses, data, xml_doc) do
    # Identify template row groups (consecutive template rows with same list_key)
    template_groups = identify_template_groups(row_analyses)

    # Process template groups in reverse order to maintain positions
    modified_table =
      template_groups
      |> Enum.reverse()
      |> Enum.reduce(table, fn group, acc_table ->
        duplicate_and_replace_group(group, data, acc_table)
      end)

    # Replace the old table with modified table in the document
    replace_table_in_doc(xml_doc, table, modified_table)
  end

  @spec identify_template_groups([Table.row_analysis()]) ::
          [%{rows: [Xml.xml_element()], list_key: String.t(), position: non_neg_integer()}]
  defp identify_template_groups(row_analyses) do
    row_analyses
    |> Enum.with_index()
    |> Enum.reduce([], &add_template_row_to_groups/2)
    |> Enum.reverse()
  end

  @spec add_template_row_to_groups({Table.row_analysis(), non_neg_integer()}, [map()]) :: [map()]
  defp add_template_row_to_groups({analysis, index}, acc) do
    if analysis.template? do
      handle_template_row(analysis, index, acc)
    else
      acc
    end
  end

  @spec handle_template_row(Table.row_analysis(), non_neg_integer(), [map()]) :: [map()]
  defp handle_template_row(analysis, index, []),
    do: [%{rows: [analysis.row], list_key: analysis.list_key, position: index}]

  defp handle_template_row(analysis, _index, [current | rest]) when current.list_key == analysis.list_key do
    updated_current = %{current | rows: current.rows ++ [analysis.row]}
    [updated_current | rest]
  end

  defp handle_template_row(analysis, index, groups) do
    [%{rows: [analysis.row], list_key: analysis.list_key, position: index} | groups]
  end

  @spec duplicate_and_replace_group(
          %{rows: [Xml.xml_element()], list_key: String.t(), position: non_neg_integer()},
          map(),
          Xml.xml_element()
        ) :: Xml.xml_element()
  defp duplicate_and_replace_group(group, data, table) do
    # Duplicate rows with scoped data
    duplicated_with_data = Table.duplicate_rows(group.rows, group.list_key, data)

    # Replace placeholders in each duplicated row
    duplicated_rows =
      Enum.map(duplicated_with_data, fn {row, scoped_data} ->
        # Apply replacement to this row with scoped data
        case Replacement.replace_in_document(row, scoped_data) do
          {:ok, replaced_row} -> replaced_row
          {:error, _} -> row
        end
      end)

    # Insert duplicated rows first, then remove template rows
    table
    |> Table.insert_rows(duplicated_rows, group.position)
    |> Table.remove_template_rows(group.rows)
  end

  @spec replace_table_in_doc(Xml.xml_element(), Xml.xml_element(), Xml.xml_element()) ::
          {:ok, Xml.xml_element()}
  defp replace_table_in_doc(xml_doc, old_table, new_table) do
    # Traverse document and replace old table with new table
    modified_doc = replace_element_in_tree(xml_doc, old_table, new_table)
    {:ok, modified_doc}
  end

  @spec replace_element_in_tree(Xml.xml_element(), Xml.xml_element(), Xml.xml_element()) ::
          Xml.xml_element()
  defp replace_element_in_tree(element, old_element, new_element) do
    import Xml

    # If this is the element to replace, return the new one
    if element == old_element do
      new_element
    else
      # Otherwise, recursively process children
      content = xmlElement(element, :content)
      modified_content = Enum.map(content, &replace_node_in_tree(&1, old_element, new_element))
      xmlElement(element, content: modified_content)
    end
  end

  @spec replace_node_in_tree(Xml.xml_node(), Xml.xml_element(), Xml.xml_element()) ::
          Xml.xml_node()
  defp replace_node_in_tree(node, old_element, new_element) do
    require Record

    if Record.is_record(node, :xmlElement) do
      replace_element_in_tree(node, old_element, new_element)
    else
      node
    end
  end

  # Loads and parses all XML files from an extracted .docx template
  @spec load_and_parse_template(Path.t(), Path.t()) :: {:ok, Template.t()} | {:error, term()}
  defp load_and_parse_template(temp_dir, source_path) do
    with {:ok, document_xml} <- load_and_parse_xml(temp_dir, "word/document.xml"),
         {:ok, headers} <- load_headers(temp_dir),
         {:ok, footers} <- load_footers(temp_dir),
         {:ok, footnotes} <- load_optional_xml(temp_dir, "word/footnotes.xml"),
         {:ok, endnotes} <- load_optional_xml(temp_dir, "word/endnotes.xml"),
         {:ok, core_props} <- load_optional_xml(temp_dir, "docProps/core.xml"),
         {:ok, app_props} <- load_optional_xml(temp_dir, "docProps/app.xml"),
         {:ok, static_files} <- load_static_files(temp_dir) do
      template =
        Template.new(
          document: document_xml,
          headers: headers,
          footers: footers,
          footnotes: footnotes,
          endnotes: endnotes,
          core_properties: core_props,
          app_properties: app_props,
          static_files: static_files,
          source_path: source_path
        )

      {:ok, template}
    end
  end

  # Renders a document from a pre-loaded Template struct
  @spec render_from_template(Template.t(), map(), Path.t()) :: :ok | {:error, term()}
  defp render_from_template(template, data, output_path) do
    # Clone the template's XML structures (they'll be modified during processing)
    document = Template.clone_xml(template.document)
    headers = Template.clone_xml_map(template.headers)
    footers = Template.clone_xml_map(template.footers)
    footnotes = if template.footnotes, do: Template.clone_xml(template.footnotes), else: nil
    endnotes = if template.endnotes, do: Template.clone_xml(template.endnotes), else: nil

    core_props =
      if template.core_properties, do: Template.clone_xml(template.core_properties), else: nil

    app_props =
      if template.app_properties, do: Template.clone_xml(template.app_properties), else: nil

    # Process the cloned XML structures
    with {:ok, processed_doc} <- process_xml_document(document, data),
         {:ok, processed_headers} <- process_xml_map(headers, data),
         {:ok, processed_footers} <- process_xml_map(footers, data),
         {:ok, processed_footnotes} <- process_optional_xml(footnotes, data),
         {:ok, processed_endnotes} <- process_optional_xml(endnotes, data),
         {:ok, processed_core} <- process_optional_xml_properties(core_props, data),
         {:ok, processed_app} <- process_optional_xml_properties(app_props, data),
         {:ok, file_map} <-
           build_output_file_map(
             template.static_files,
             processed_doc,
             processed_headers,
             processed_footers,
             processed_footnotes,
             processed_endnotes,
             processed_core,
             processed_app
           ) do
      Archive.create(file_map, output_path)
    end
  end

  # Loads and parses a single XML file with normalization
  @spec load_and_parse_xml(Path.t(), String.t()) :: {:ok, Xml.xml_element()} | {:error, term()}
  defp load_and_parse_xml(temp_dir, relative_path) do
    file_path = Path.join(temp_dir, relative_path)

    with {:ok, xml_content} <- File.read(file_path),
         {:ok, xml_doc} <- Xml.parse(xml_content) do
      {:ok, Normalizer.normalize(xml_doc)}
    else
      {:error, reason} -> {:error, {:load_xml_failed, relative_path, reason}}
    end
  end

  # Loads all header XML files
  @spec load_headers(Path.t()) :: {:ok, %{String.t() => Xml.xml_element()}} | {:error, term()}
  defp load_headers(temp_dir) do
    load_xml_files_by_pattern(temp_dir, "word/header*.xml")
  end

  # Loads all footer XML files
  @spec load_footers(Path.t()) :: {:ok, %{String.t() => Xml.xml_element()}} | {:error, term()}
  defp load_footers(temp_dir) do
    load_xml_files_by_pattern(temp_dir, "word/footer*.xml")
  end

  # Loads XML files matching a glob pattern
  @spec load_xml_files_by_pattern(Path.t(), String.t()) ::
          {:ok, %{String.t() => Xml.xml_element()}} | {:error, term()}
  defp load_xml_files_by_pattern(temp_dir, pattern) do
    files = Path.wildcard(Path.join(temp_dir, pattern))

    result =
      Enum.reduce_while(files, {:ok, %{}}, fn file_path, {:ok, acc} ->
        relative_path = Path.relative_to(file_path, temp_dir)

        case load_and_parse_xml(temp_dir, relative_path) do
          {:ok, xml} -> {:cont, {:ok, Map.put(acc, relative_path, xml)}}
          {:error, _reason} = error -> {:halt, error}
        end
      end)

    result
  end

  # Loads an optional XML file (returns nil if missing)
  @spec load_optional_xml(Path.t(), String.t()) :: {:ok, Xml.xml_element() | nil} | {:error, term()}
  defp load_optional_xml(temp_dir, relative_path) do
    file_path = Path.join(temp_dir, relative_path)

    if File.exists?(file_path) do
      case load_and_parse_xml(temp_dir, relative_path) do
        {:ok, xml} -> {:ok, xml}
        {:error, _reason} = error -> error
      end
    else
      {:ok, nil}
    end
  end

  # Loads static files that don't need processing (relationships, content types, media, etc.)
  @spec load_static_files(Path.t()) :: {:ok, %{String.t() => binary()}} | {:error, term()}
  defp load_static_files(temp_dir) do
    # Static files are everything except the XML files we process
    processable_patterns = [
      "word/document.xml",
      "word/header*.xml",
      "word/footer*.xml",
      "word/footnotes.xml",
      "word/endnotes.xml",
      "docProps/core.xml",
      "docProps/app.xml"
    ]

    processable_files =
      processable_patterns
      |> Enum.flat_map(&Path.wildcard(Path.join(temp_dir, &1)))
      |> MapSet.new()

    # Gather all files
    case gather_files(temp_dir, temp_dir) do
      {:ok, all_files} ->
        # Filter out processable XML files
        static_files =
          all_files
          |> Enum.reject(fn {relative_path, _content} ->
            full_path = Path.join(temp_dir, relative_path)
            MapSet.member?(processable_files, full_path)
          end)
          |> Map.new()

        {:ok, static_files}

      {:error, reason} ->
        {:error, {:load_static_files_failed, reason}}
    end
  end

  # Processes an XML document through the full pipeline
  @spec process_xml_document(Xml.xml_element(), map()) :: {:ok, Xml.xml_element()} | {:error, term()}
  defp process_xml_document(xml_doc, data) do
    with {:ok, conditional_processed} <- process_conditionals(xml_doc, data),
         {:ok, table_processed} <- process_tables(conditional_processed, data),
         {:ok, replaced} <- Replacement.replace_in_document(table_processed, data),
         {:ok, image_processed} <- process_images_in_memory(replaced, data) do
      {:ok, image_processed}
    end
  end

  # Processes a map of XML documents
  @spec process_xml_map(%{String.t() => Xml.xml_element()}, map()) ::
          {:ok, %{String.t() => Xml.xml_element()}} | {:error, term()}
  defp process_xml_map(xml_map, data) do
    result =
      Enum.reduce_while(xml_map, {:ok, %{}}, fn {key, xml}, {:ok, acc} ->
        case process_xml_document(xml, data) do
          {:ok, processed_xml} -> {:cont, {:ok, Map.put(acc, key, processed_xml)}}
          {:error, _reason} = error -> {:halt, error}
        end
      end)

    result
  end

  # Processes an optional XML document
  @spec process_optional_xml(Xml.xml_element() | nil, map()) ::
          {:ok, Xml.xml_element() | nil} | {:error, term()}
  defp process_optional_xml(nil, _data), do: {:ok, nil}
  defp process_optional_xml(xml, data), do: process_xml_document(xml, data)

  # Processes optional property XML (simpler pipeline, no conditionals/tables)
  @spec process_optional_xml_properties(Xml.xml_element() | nil, map()) ::
          {:ok, Xml.xml_element() | nil} | {:error, term()}
  defp process_optional_xml_properties(nil, _data), do: {:ok, nil}

  defp process_optional_xml_properties(xml, data) do
    Replacement.replace_in_document(xml, data)
  end

  # Processes images in memory (without temp_dir)
  @spec process_images_in_memory(Xml.xml_element(), map()) ::
          {:ok, Xml.xml_element()} | {:error, term()}
  defp process_images_in_memory(xml_doc, _data) do
    # For now, just return the document unchanged
    # Image processing would need temp_dir for relationships/content types
    # This can be enhanced later if needed for batch operations
    {:ok, xml_doc}
  end

  # Builds output file map from processed XML and static files
  @spec build_output_file_map(
          %{String.t() => binary()},
          Xml.xml_element(),
          %{String.t() => Xml.xml_element()},
          %{String.t() => Xml.xml_element()},
          Xml.xml_element() | nil,
          Xml.xml_element() | nil,
          Xml.xml_element() | nil,
          Xml.xml_element() | nil
        ) :: {:ok, Archive.file_map()} | {:error, term()}
  defp build_output_file_map(
         static_files,
         document,
         headers,
         footers,
         footnotes,
         endnotes,
         core_props,
         app_props
       ) do
    # Serialize all XML back to strings
    with {:ok, document_xml} <- Xml.serialize(document),
         {:ok, headers_map} <- serialize_xml_map(headers),
         {:ok, footers_map} <- serialize_xml_map(footers),
         {:ok, footnotes_xml} <- serialize_optional(footnotes),
         {:ok, endnotes_xml} <- serialize_optional(endnotes),
         {:ok, core_xml} <- serialize_optional(core_props),
         {:ok, app_xml} <- serialize_optional(app_props) do
      file_map =
        static_files
        |> Map.put("word/document.xml", document_xml)
        |> Map.merge(headers_map)
        |> Map.merge(footers_map)
        |> maybe_put("word/footnotes.xml", footnotes_xml)
        |> maybe_put("word/endnotes.xml", endnotes_xml)
        |> maybe_put("docProps/core.xml", core_xml)
        |> maybe_put("docProps/app.xml", app_xml)

      {:ok, file_map}
    end
  end

  # Serializes a map of XML elements
  @spec serialize_xml_map(%{String.t() => Xml.xml_element()}) ::
          {:ok, %{String.t() => binary()}} | {:error, term()}
  defp serialize_xml_map(xml_map) do
    result =
      Enum.reduce_while(xml_map, {:ok, %{}}, fn {key, xml}, {:ok, acc} ->
        case Xml.serialize(xml) do
          {:ok, xml_string} -> {:cont, {:ok, Map.put(acc, key, xml_string)}}
          {:error, _reason} = error -> {:halt, error}
        end
      end)

    result
  end

  # Serializes optional XML
  @spec serialize_optional(Xml.xml_element() | nil) :: {:ok, binary() | nil} | {:error, term()}
  defp serialize_optional(nil), do: {:ok, nil}
  defp serialize_optional(xml), do: Xml.serialize(xml)

  # Conditionally puts a value in map if not nil
  @spec maybe_put(map(), String.t(), any()) :: map()
  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  @spec validate_output_path(Path.t()) :: :ok | {:error, term()}
  defp validate_output_path(output_path) do
    if File.dir?(Path.dirname(output_path)) do
      :ok
    else
      {:error,
       {:invalid_output_path, "Output directory does not exist: #{Path.dirname(output_path)}"}}
    end
  end

  @spec validate_paths(Path.t(), Path.t()) :: :ok | {:error, term()}
  defp validate_paths(template_path, output_path) do
    cond do
      Path.expand(template_path) == Path.expand(output_path) ->
        {:error, {:same_file, "Template and output paths must be different"}}

      not File.dir?(Path.dirname(output_path)) ->
        {:error, {:invalid_output_path, "Output directory does not exist: #{Path.dirname(output_path)}"}}

      true ->
        :ok
    end
  end

  @spec build_file_map(Path.t()) :: {:ok, Archive.file_map()} | {:error, term()}
  defp build_file_map(temp_dir) do
    # Recursively find all files in temp directory
    case gather_files(temp_dir, temp_dir) do
      {:ok, file_map} -> {:ok, file_map}
      {:error, reason} -> {:error, {:build_file_map_failed, reason}}
    end
  end

  @spec gather_files(Path.t(), Path.t()) :: {:ok, Archive.file_map()} | {:error, term()}
  defp gather_files(base_dir, current_dir) do
    case File.ls(current_dir) do
      {:ok, entries} ->
        file_map =
          Enum.reduce(entries, %{}, fn entry, acc ->
            process_entry(base_dir, current_dir, entry, acc)
          end)

        {:ok, file_map}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec process_entry(Path.t(), Path.t(), String.t(), Archive.file_map()) :: Archive.file_map()
  defp process_entry(base_dir, current_dir, entry, acc) do
    full_path = Path.join(current_dir, entry)
    relative_path = Path.relative_to(full_path, base_dir)

    cond do
      File.regular?(full_path) ->
        add_file_to_map(relative_path, full_path, acc)

      File.dir?(full_path) ->
        merge_directory_contents(base_dir, full_path, acc)

      true ->
        acc
    end
  end

  @spec add_file_to_map(String.t(), Path.t(), Archive.file_map()) :: Archive.file_map()
  defp add_file_to_map(relative_path, full_path, acc) do
    case File.read(full_path) do
      {:ok, content} -> Map.put(acc, relative_path, content)
      {:error, _} -> acc
    end
  end

  @spec merge_directory_contents(Path.t(), Path.t(), Archive.file_map()) :: Archive.file_map()
  defp merge_directory_contents(base_dir, full_path, acc) do
    case gather_files(base_dir, full_path) do
      {:ok, nested_map} -> Map.merge(acc, nested_map)
      {:error, _} -> acc
    end
  end

  # Processes images in an XML document.
  #
  # Finds placeholder images (using Image.find_placeholder_images/1), validates image files,
  # embeds them into the archive, updates relationships and content types, and updates
  # image references in the document.
  #
  # This must run AFTER variable replacement to ensure placeholders in data are resolved first.
  @spec process_images(Xml.xml_element(), map(), Path.t()) ::
          {:ok, Xml.xml_element()} | {:error, term()}
  defp process_images(xml_doc, data, temp_dir) do
    # Find all placeholder images in the document
    placeholders = Image.find_placeholder_images(xml_doc)

    # If no placeholders, return document unchanged
    if Enum.empty?(placeholders) do
      {:ok, xml_doc}
    else
      # Process each placeholder
      process_all_image_placeholders(xml_doc, placeholders, data, temp_dir)
    end
  end

  # Processes all image placeholders
  @spec process_all_image_placeholders(
          Xml.xml_element(),
          [map()],
          map(),
          Path.t()
        ) :: {:ok, Xml.xml_element()} | {:error, term()}
  defp process_all_image_placeholders(xml_doc, placeholders, data, temp_dir) do
    # Load relationships file
    rels_path = Path.join(temp_dir, "word/_rels/document.xml.rels")

    with {:ok, rels_xml} <- load_relationships(rels_path),
         {:ok, content_types_xml} <- load_content_types(temp_dir),
         {:ok, modified_doc, updated_rels, updated_types} <-
           process_each_placeholder(xml_doc, placeholders, data, temp_dir, rels_xml, content_types_xml),
         :ok <- save_relationships(rels_path, updated_rels),
         :ok <- save_content_types(temp_dir, updated_types) do
      {:ok, modified_doc}
    end
  end

  # Processes each placeholder sequentially
  @spec process_each_placeholder(
          Xml.xml_element(),
          [map()],
          map(),
          Path.t(),
          Xml.xml_element(),
          tuple()
        ) :: {:ok, Xml.xml_element(), Xml.xml_element(), tuple()} | {:error, term()}
  defp process_each_placeholder(xml_doc, [], _data, _temp_dir, rels_xml, content_types_xml) do
    {:ok, xml_doc, rels_xml, content_types_xml}
  end

  defp process_each_placeholder(xml_doc, [placeholder | rest], data, temp_dir, rels_xml, content_types_xml) do
    with {:ok, modified_doc, updated_rels, updated_types} <-
           process_single_image_placeholder(
             xml_doc,
             placeholder,
             data,
             temp_dir,
             rels_xml,
             content_types_xml
           ) do
      process_each_placeholder(modified_doc, rest, data, temp_dir, updated_rels, updated_types)
    end
  end

  # Processes a single image placeholder
  @spec process_single_image_placeholder(
          Xml.xml_element(),
          map(),
          map(),
          Path.t(),
          Xml.xml_element(),
          tuple()
        ) :: {:ok, Xml.xml_element(), Xml.xml_element(), tuple()} | {:error, term()}
  defp process_single_image_placeholder(xml_doc, placeholder, data, temp_dir, rels_xml, content_types_xml) do
    # Get image path from data
    image_path = Map.get(data, placeholder.placeholder_name)

    if is_nil(image_path) do
      {:error,
       Ootempl.ImageError.exception(
         placeholder_name: placeholder.placeholder_name,
         image_path: nil,
         reason: :image_not_found_in_data
       )}
    else
      with :ok <- Image.validate_image_file(image_path),
           {:ok, image_dims} <- Image.get_image_dimensions(image_path),
           {scaled_width, scaled_height} <-
             Image.calculate_scaled_dimensions(image_dims, placeholder.template_dimensions),
           extension = Path.extname(image_path),
           existing_ids = Relationships.extract_relationship_ids(rels_xml),
           new_rel_id = Relationships.generate_unique_id(existing_ids),
           existing_media_files = list_existing_media_files(temp_dir),
           media_filename = Image.generate_media_filename(existing_media_files, extension),
           :ok <- embed_image_to_media(temp_dir, image_path, media_filename) do
        relationship =
          Relationships.create_image_relationship(new_rel_id, "media/#{media_filename}")

        updated_rels = Relationships.add_relationship(rels_xml, relationship)
        mime_type = Image.mime_type_for_extension(extension)
        updated_types = add_image_content_type(content_types_xml, extension, mime_type)

        modified_doc =
          update_image_reference(
            xml_doc,
            placeholder,
            new_rel_id,
            scaled_width,
            scaled_height
          )

        {:ok, modified_doc, updated_rels, updated_types}
      else
        {:error, atom} when is_atom(atom) ->
          {:error,
           Ootempl.ImageError.exception(
             placeholder_name: placeholder.placeholder_name,
             image_path: image_path,
             reason: atom
           )}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  # Loads relationships XML from file
  @spec load_relationships(Path.t()) :: {:ok, Xml.xml_element()} | {:error, term()}
  defp load_relationships(rels_path) do
    with {:ok, xml_content} <- File.read(rels_path),
         {:ok, rels_xml} <- Relationships.parse_relationships(xml_content) do
      {:ok, rels_xml}
    else
      {:error, reason} -> {:error, {:load_relationships_failed, reason}}
    end
  end

  # Loads content types XML from file
  @spec load_content_types(Path.t()) :: {:ok, tuple()} | {:error, term()}
  defp load_content_types(temp_dir) do
    content_types_path = Path.join(temp_dir, "[Content_Types].xml")

    with {:ok, xml_content} <- File.read(content_types_path),
         {:ok, types_xml} <- Image.parse_content_types(xml_content) do
      {:ok, types_xml}
    else
      {:error, reason} -> {:error, {:load_content_types_failed, reason}}
    end
  end

  # Saves relationships XML to file
  @spec save_relationships(Path.t(), Xml.xml_element()) :: :ok | {:error, term()}
  defp save_relationships(rels_path, rels_xml) do
    with {:ok, xml_string} <- Relationships.serialize_relationships(rels_xml),
         :ok <- File.write(rels_path, xml_string) do
      :ok
    else
      {:error, reason} -> {:error, {:save_relationships_failed, reason}}
    end
  end

  # Saves content types XML to file
  @spec save_content_types(Path.t(), tuple()) :: :ok | {:error, term()}
  defp save_content_types(temp_dir, types_xml) do
    content_types_path = Path.join(temp_dir, "[Content_Types].xml")
    xml_string = Image.serialize_content_types(types_xml)

    case File.write(content_types_path, xml_string) do
      :ok -> :ok
      {:error, reason} -> {:error, {:save_content_types_failed, reason}}
    end
  end

  # Lists existing media files in the word/media directory
  @spec list_existing_media_files(Path.t()) :: [String.t()]
  defp list_existing_media_files(temp_dir) do
    media_dir = Path.join(temp_dir, "word/media")

    case File.ls(media_dir) do
      {:ok, files} -> files
      {:error, _} -> []
    end
  end

  # Embeds image file into the word/media directory
  @spec embed_image_to_media(Path.t(), String.t(), String.t()) :: :ok | {:error, term()}
  defp embed_image_to_media(temp_dir, image_path, media_filename) do
    media_dir = Path.join(temp_dir, "word/media")
    File.mkdir_p(media_dir)

    destination_path = Path.join(media_dir, media_filename)

    case File.copy(image_path, destination_path) do
      {:ok, _bytes} -> :ok
      {:error, reason} -> {:error, {:copy_image_failed, reason}}
    end
  end

  # Adds image content type to content types XML
  @spec add_image_content_type(tuple(), String.t(), String.t()) :: tuple()
  defp add_image_content_type(content_types_xml, extension, mime_type) do
    # Remove leading dot from extension if present
    normalized_ext = String.trim_leading(extension, ".")
    Image.add_content_type(content_types_xml, normalized_ext, mime_type)
  end

  # Updates image reference in the document with new relationship ID and dimensions
  @spec update_image_reference(
          Xml.xml_element(),
          map(),
          String.t(),
          float(),
          float()
        ) :: Xml.xml_element()
  defp update_image_reference(xml_doc, placeholder, new_rel_id, scaled_width, scaled_height) do
    # Find the blip element within the drawing
    blip_element = find_blip_in_drawing(placeholder.xml_element)

    if is_nil(blip_element) do
      xml_doc
    else
      # Update the r:embed attribute to point to new relationship ID
      updated_blip = update_blip_relationship(blip_element, new_rel_id)

      # Find extent element and update dimensions
      extent_element = find_extent_in_drawing(placeholder.xml_element)

      updated_extent =
        if is_nil(extent_element) do
          nil
        else
          update_extent_dimensions(extent_element, scaled_width, scaled_height)
        end

      # Replace blip and extent in the document
      xml_doc
      |> replace_element_in_tree(blip_element, updated_blip)
      |> maybe_replace_extent(extent_element, updated_extent)
    end
  end

  # Conditionally replaces extent element if both old and new are present
  @spec maybe_replace_extent(Xml.xml_element(), tuple() | nil, tuple() | nil) ::
          Xml.xml_element()
  defp maybe_replace_extent(xml_doc, nil, _new_extent), do: xml_doc
  defp maybe_replace_extent(xml_doc, _old_extent, nil), do: xml_doc

  defp maybe_replace_extent(xml_doc, old_extent, new_extent) do
    replace_element_in_tree(xml_doc, old_extent, new_extent)
  end

  # Finds blip element in a drawing element
  @spec find_blip_in_drawing(tuple()) :: tuple() | nil
  defp find_blip_in_drawing(drawing_element) do
    import Xml

    case drawing_element do
      xmlElement(name: name, content: content) ->
        current_name = name |> Atom.to_string() |> String.split(":") |> List.last()

        if current_name == "blip" do
          drawing_element
        else
          Enum.find_value(content, &find_blip_in_drawing/1)
        end

      _ ->
        nil
    end
  end

  # Finds extent element in a drawing element
  @spec find_extent_in_drawing(tuple()) :: tuple() | nil
  defp find_extent_in_drawing(drawing_element) do
    import Xml

    case drawing_element do
      xmlElement(name: name, content: content) ->
        current_name = name |> Atom.to_string() |> String.split(":") |> List.last()

        if current_name == "extent" do
          drawing_element
        else
          Enum.find_value(content, &find_extent_in_drawing/1)
        end

      _ ->
        nil
    end
  end

  # Updates blip element's r:embed attribute
  @spec update_blip_relationship(tuple(), String.t()) :: tuple()
  defp update_blip_relationship(blip_element, new_rel_id) do
    import Xml

    xmlElement(attributes: attrs) = blip_element

    # Update or add r:embed attribute
    updated_attrs =
      Enum.map(attrs, fn attr ->
        xmlAttribute(name: name) = attr
        attr_name_str = Atom.to_string(name)

        if String.ends_with?(attr_name_str, "embed") do
          xmlAttribute(attr, value: String.to_charlist(new_rel_id))
        else
          attr
        end
      end)

    xmlElement(blip_element, attributes: updated_attrs)
  end

  # Updates extent element's cx and cy attributes (dimensions in EMUs)
  @spec update_extent_dimensions(tuple(), float(), float()) :: tuple()
  defp update_extent_dimensions(extent_element, width, height) do
    import Xml

    xmlElement(attributes: attrs) = extent_element

    # Convert to EMUs (English Metric Units): 1 pixel ≈ 9525 EMUs at 96 DPI
    # However, we should preserve the scale of the original template dimensions
    # The scaled_width and scaled_height are already in the same units as template_dimensions
    # So we just need to round them to integers

    width_emus = round(width)
    height_emus = round(height)

    # Update cx and cy attributes
    updated_attrs =
      Enum.map(attrs, fn attr ->
        xmlAttribute(name: name) = attr
        attr_name = Atom.to_string(name)

        cond do
          attr_name == "cx" ->
            xmlAttribute(attr, value: Integer.to_charlist(width_emus))

          attr_name == "cy" ->
            xmlAttribute(attr, value: Integer.to_charlist(height_emus))

          true ->
            attr
        end
      end)

    xmlElement(extent_element, attributes: updated_attrs)
  end
end
