defmodule PipeTrace.MermaidTest do
  use ExUnit.Case
  alias PipeTrace.Mermaid

  @expected_diagram """
```mermaid
sequenceDiagram
participant MyAppWeb.FakeController
participant MyApp.Accounts
MyAppWeb.FakeController->>MyApp.Accounts: normalize
MyApp.Accounts-->>MyAppWeb.FakeController: normalize response
MyAppWeb.FakeController->>MyApp.Accounts: create_user
MyApp.Accounts-->>MyAppWeb.FakeController: create_user response
```
"""

  describe "generate/2" do
    test "creates a correct Mermaid sequence diagram from AST" do
      File.rm("sequence_diagram.md")

      {module_name, calls} = PipeTrace.Trace.from_source_file("test/fixtures/fake_controller.ex", :create)
      Mermaid.generate(calls, module_name)

      assert File.exists?("sequence_diagram.md")
      content = File.read!("sequence_diagram.md")
      assert content == @expected_diagram
    end

    test "generates diagram with single function call" do
      File.rm("sequence_diagram.md")
      
      Mermaid.generate(["MyApp.Utils.process"], "MyAppWeb.FakeController")
      
      assert File.exists?("sequence_diagram.md")
      content = File.read!("sequence_diagram.md")
      
      assert content =~ "participant MyAppWeb.FakeController"
      assert content =~ "participant MyApp.Utils"
      assert content =~ "MyAppWeb.FakeController->>MyApp.Utils: process"
      assert content =~ "MyApp.Utils-->>MyAppWeb.FakeController: process response"
    end

    test "generates diagram with multiple different modules" do
      File.rm("sequence_diagram.md")
      
      calls = [
        "MyApp.Users.validate",
        "MyApp.Accounts.create",
        "MyApp.Notifications.send"
      ]
      
      Mermaid.generate(calls, "MyAppWeb.FakeController")
      
      assert File.exists?("sequence_diagram.md")
      content = File.read!("sequence_diagram.md")
      
      assert content =~ "participant MyAppWeb.FakeController"
      assert content =~ "participant MyApp.Users"
      assert content =~ "participant MyApp.Accounts"
      assert content =~ "participant MyApp.Notifications"
      assert content =~ "MyAppWeb.FakeController->>MyApp.Users: validate"
      assert content =~ "MyApp.Users-->>MyAppWeb.FakeController: validate response"
      assert content =~ "MyAppWeb.FakeController->>MyApp.Accounts: create"
      assert content =~ "MyApp.Accounts-->>MyAppWeb.FakeController: create response"
      assert content =~ "MyAppWeb.FakeController->>MyApp.Notifications: send"
      assert content =~ "MyApp.Notifications-->>MyAppWeb.FakeController: send response"
    end

    test "handles empty list of calls" do
      File.rm("sequence_diagram.md")
      
      Mermaid.generate([], "MyAppWeb.FakeController")
      
      assert File.exists?("sequence_diagram.md")
      content = File.read!("sequence_diagram.md")
      
      assert content =~ "participant MyAppWeb.FakeController"
      # Should only have the controller participant
      assert content =~ "```mermaid"
      assert content =~ "sequenceDiagram"
      assert content =~ "```"
    end

    test "handles calls with pipe operators" do
      File.rm("sequence_diagram.md")
      
      calls = ["params |> MyApp.Accounts.normalize", "MyApp.Accounts.create_user"]
      
      Mermaid.generate(calls, "MyAppWeb.FakeController")
      
      assert File.exists?("sequence_diagram.md")
      content = File.read!("sequence_diagram.md")
      
      assert content =~ "participant MyAppWeb.FakeController"
      assert content =~ "participant MyApp.Accounts"
      assert content =~ "MyAppWeb.FakeController->>MyApp.Accounts: normalize"
      assert content =~ "MyApp.Accounts-->>MyAppWeb.FakeController: normalize response"
      assert content =~ "MyAppWeb.FakeController->>MyApp.Accounts: create_user"
      assert content =~ "MyApp.Accounts-->>MyAppWeb.FakeController: create_user response"
    end

    test "filters out non-module participants" do
      File.rm("sequence_diagram.md")
      
      calls = ["params", "MyApp.Utils.process", "result"]
      
      Mermaid.generate(calls, "MyAppWeb.FakeController")
      
      assert File.exists?("sequence_diagram.md")
      content = File.read!("sequence_diagram.md")
      
      # Should not include params or result as participants
      refute content =~ "participant params"
      refute content =~ "participant result"
      assert content =~ "participant MyApp.Utils"
    end

    test "handles function names with colons" do
      File.rm("sequence_diagram.md")
      
      calls = ["MyApp.Utils.:process", "MyApp.Utils.:validate"]
      
      Mermaid.generate(calls, "MyAppWeb.FakeController")
      
      assert File.exists?("sequence_diagram.md")
      content = File.read!("sequence_diagram.md")
      
      assert content =~ "MyAppWeb.FakeController->>MyApp.Utils: process"
      assert content =~ "MyApp.Utils-->>MyAppWeb.FakeController: process response"
      assert content =~ "MyAppWeb.FakeController->>MyApp.Utils: validate"
      assert content =~ "MyApp.Utils-->>MyAppWeb.FakeController: validate response"
    end

    test "creates proper Mermaid syntax" do
      File.rm("sequence_diagram.md")
      
      Mermaid.generate(["MyApp.Utils.process"], "MyAppWeb.FakeController")
      
      content = File.read!("sequence_diagram.md")
      
      # Check for proper Mermaid syntax
      assert content =~ "```mermaid"
      assert content =~ "sequenceDiagram"
      assert content =~ "participant"
      assert content =~ "->>"
      assert content =~ "```"
      # Should end with newline
      assert content =~ "\n```\n"
    end
  end
end
