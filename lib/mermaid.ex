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
  @spec build_participants([String.t()], String.t()) :: [String.t()]
  defp build_participants(calls, module_name) do
    # Add the controller as the first participant dynamically
    participants = [module_name] ++ 
      (calls
       |> Enum.map(&participant_from/1)
       |> Enum.filter(&is_module?/1)
       |> Enum.uniq())
    
    participants
    |> Enum.map(&"participant #{&1}")
  end

  defp build_messages([], _module_name), do: []

  @doc false
  @spec build_messages([String.t()], String.t()) :: [String.t()]
  defp build_messages(calls, module_name) when length(calls) >= 1 do
    # Start with controller calling the first function
    first_call = List.first(calls)
    first_message = ["#{module_name}->>#{participant_from(first_call)}: #{extract_function_name(first_call)}"]
    
    # Then add messages between subsequent calls
    if length(calls) >= 2 do
      rest_messages = build_messages_between_calls(calls)
      first_message ++ rest_messages
    else
      first_message
    end
  end

  @doc false
  @spec build_messages_between_calls([String.t()]) :: [String.t()]
  defp build_messages_between_calls([_]), do: []

  @doc false
  @spec build_messages_between_calls([String.t()]) :: [String.t()]
  defp build_messages_between_calls([from, to | rest]) do
    ["#{participant_from(from)}->>#{participant_from(to)}: #{extract_function_name(to)}"] ++
      build_messages_between_calls([to | rest])
  end

  @doc false
  @spec build_messages_between_calls([]) :: []
  defp build_messages_between_calls([]), do: []

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
