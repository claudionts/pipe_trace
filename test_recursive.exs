#!/usr/bin/env elixir

# Test script for recursive function call analysis
result = PipeTrace.Trace.from_source_file("test/fixtures/custom_controller.ex", :create)
IO.inspect(result, label: "Recursive Analysis Result")

# Generate diagram
PipeTrace.generate_diagram("test/fixtures/custom_controller.ex", :create)

# Read and display the generated diagram
content = File.read!("sequence_diagram.md")
IO.puts("\nGenerated Diagram:")
IO.puts(content) 