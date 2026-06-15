# Manual verification tests generate documents for a human to open in Word.
# They are excluded by default; run them explicitly with `mix test --only manual`.
ExUnit.start(exclude: [:manual])

# All test-generated artifacts (rendered documents, manual outputs) are written
# under this git-ignored directory rather than test/fixtures/, which is reserved
# for hand-crafted input fixtures.
File.mkdir_p!("tmp")

# Load test support modules
Code.require_file("support/fixture_helper.ex", __DIR__)
Code.require_file("support/ootempl_test_helpers.ex", __DIR__)
