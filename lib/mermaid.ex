defmodule PipeTrace.Mermaid do
  @moduledoc """
  Generates Mermaid sequence diagrams from function call lists.

  This module takes a list of function calls extracted from Elixir code
  and generates a Mermaid sequence diagram showing the flow between
  different modules and their function calls. The module name is extracted
  dynamically from the source file, making it generic for any project.

  ## Examples

      iex> calls = ["MyApp.Accounts.normalize", "MyApp.Accounts.create_user"]
      iex> PipeTrace.Mermaid.generate(calls, "MyAppWeb.UserController")
      ✅ Diagram saved in sequence_diagram.md
      :ok

  The generated diagram will be saved to `sequence_diagram.md` and will
  show the sequence of function calls between participants (modules).
  """

  @doc """
  Generates a Mermaid sequence diagram from a list of function calls.

  Takes a list of function call strings and creates a Mermaid sequence diagram
  that shows the flow between different modules. The diagram is saved to
  `sequence_diagram.md` in the current directory.

  ## Parameters

    - `calls` - A list of function call strings (e.g., `["MyApp.Accounts.normalize", "MyApp.Accounts.create_user"]`)
    - `module_name` - The name of the module being analyzed (e.g., `"MyAppWeb.UserController"`)

  ## Returns

    - `:ok` - When the diagram is successfully generated and saved

  ## Examples

      iex> PipeTrace.Mermaid.generate(["MyApp.Accounts.normalize", "MyApp.Accounts.create_user"], "MyAppWeb.UserController")
      ✅ Diagram saved in sequence_diagram.md
      :ok

  """
  @spec generate([String.t()], String.t()) :: :ok
  def generate(calls, module_name) do
    diagram =
      ["```mermaid", "sequenceDiagram"] ++
        build_participants(calls, module_name) ++
        build_messages(calls, module_name) ++
        ["```", ""]

    markdown = Enum.join(diagram, "\n")

    File.write!("sequence_diagram.md", markdown)
    IO.puts("✅ Diagram saved in sequence_diagram.md")
  end

  @doc false
  @spec build_participants([{String.t(), {String.t(), String.t()}}], String.t()) :: [String.t()]
  defp build_participants(call_pairs, module_name) do
    participants =
      [module_name] ++
      (call_pairs
       |> Enum.flat_map(fn {caller, {callee, _function}} -> [caller, callee] end)
       |> Enum.uniq())
    Enum.map(participants, &"participant #{&1}")
  end

  @doc false
  @spec build_messages([{String.t(), {String.t(), String.t()}}], String.t()) :: [String.t()]
  defp build_messages(call_pairs, _module_name) do
    Enum.flat_map(call_pairs, fn {caller, {callee, function}} ->
      [
        "#{caller}->>#{callee}: #{function}",
        "#{callee}-->>#{caller}: #{function} response"
      ]
    end)
  end

  @doc false
  @spec separate_direct_and_nested_calls([String.t()]) :: {[String.t()], [String.t()]}
  defp separate_direct_and_nested_calls(calls) do
    # This is a simplified approach - in a real implementation,
    # we would need to understand the call hierarchy from the AST
    # For now, let's assume the first call to each module is direct,
    # and subsequent calls to the same module are nested
    
    module_calls = Enum.group_by(calls, &participant_from/1)
    
    direct_calls = module_calls
    |> Enum.map(fn {_module, calls} -> List.first(calls) end)
    
    nested_calls = calls -- direct_calls
    
    {direct_calls, nested_calls}
  end

  @doc false
  @spec build_direct_call_messages(String.t(), [String.t()]) :: [String.t()]
  defp build_direct_call_messages(controller, calls) do
    Enum.flat_map(calls, fn call ->
      [
        "#{controller}->>#{participant_from(call)}: #{extract_function_name(call)}",
        "#{participant_from(call)}-->>#{controller}: #{extract_function_name(call)} response"
      ]
    end)
  end

  @doc false
  @spec build_nested_call_messages([String.t()]) :: [String.t()]
  defp build_nested_call_messages([]), do: []

  @doc false
  @spec build_nested_call_messages([String.t()]) :: [String.t()]
  defp build_nested_call_messages(calls) do
    # For nested calls, we need to understand which function calls which
    # This is a simplified implementation
    # In a real implementation, we would need to analyze the call hierarchy
    
    # For now, let's assume calls are in sequence
    build_sequential_nested_calls(calls)
  end

  @doc false
  @spec build_sequential_nested_calls([String.t()]) :: [String.t()]
  defp build_sequential_nested_calls([]), do: []

  defp build_sequential_nested_calls([_]), do: []

  defp build_sequential_nested_calls([from, to | rest]) do
    [
      "#{participant_from(from)}->>#{participant_from(to)}: #{extract_function_name(to)}",
      "#{participant_from(to)}-->>#{participant_from(from)}: #{extract_function_name(to)} response"
    ] ++ build_sequential_nested_calls([to | rest])
  end

  @doc false
  @spec group_calls_by_module([String.t()]) :: [{String.t(), [String.t()]}]
  defp group_calls_by_module(calls) do
    calls
    |> Enum.group_by(&participant_from/1)
    |> Enum.map(fn {module, calls} -> {module, calls} end)
  end

  @doc false
  @spec build_module_messages(String.t(), String.t(), [String.t()]) :: [String.t()]
  defp build_module_messages(controller, module, calls) do
    # Controller calls the first function in this module
    first_call = List.first(calls)
    first_message = ["#{controller}->>#{module}: #{extract_function_name(first_call)}"]
    
    # Add response from this module back to controller
    first_response = ["#{module}-->>#{controller}: #{extract_function_name(first_call)} response"]
    
    first_message ++ first_response
  end

  @doc false
  @spec build_chain_messages([String.t()]) :: [String.t()]
  defp build_chain_messages([_first]), do: []

  @doc false
  @spec build_chain_messages([String.t()]) :: [String.t()]
  defp build_chain_messages([from, to | rest]) do
    # Add call from one function to another
    call_message = ["#{participant_from(from)}->>#{participant_from(to)}: #{extract_function_name(to)}"]
    
    # Add response from the called function back to the caller
    response_message = ["#{participant_from(to)}-->>#{participant_from(from)}: #{extract_function_name(to)} response"]
    
    # Continue building the chain
    chain_rest = build_chain_messages([to | rest])
    
    call_message ++ response_message ++ chain_rest
  end

  @doc false
  @spec participant_from(String.t()) :: String.t()
  defp participant_from(call) when is_binary(call) do
    # Handle piped calls like "params |> MyApp.Accounts.normalize()"
    if String.contains?(call, "|>") do
      call
      |> String.split("|>")
      |> List.last()
      |> String.trim()
      |> extract_module_name()
    else
      extract_module_name(call)
    end
  end

  @doc false
  @spec extract_module_name(String.t()) :: String.t()
  defp extract_module_name(call) do
    # Extract module name from function calls like "MyApp.Accounts.normalize()"
    call
    |> String.split(".")
    |> Enum.take(2)  # Take first two parts for module name
    |> Enum.join(".")
    |> String.replace("()", "")  # Remove function call parentheses
  end

  @doc false
  @spec extract_function_name(String.t()) :: String.t()
  defp extract_function_name(call) do
    # Extract just the function name from calls like "MyApp.Accounts.normalize()"
    call
    |> String.split(".")
    |> List.last()
    |> String.replace("()", "")
    |> String.replace(":", "")  # Remove colon if present
  end

  @doc false
  @spec is_module?(String.t()) :: boolean()
  defp is_module?(participant) do
    # Check if the participant looks like a module name (contains a dot)
    String.contains?(participant, ".")
  end
end
