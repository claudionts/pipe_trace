defmodule PipeTrace.MermaidTest do
  use ExUnit.Case
  alias PipeTrace.Mermaid

  @expected_diagram """
```mermaid
sequenceDiagram
participant MyAppWeb.FakeController
participant MyApp.Accounts
MyAppWeb.FakeController->>MyApp.Accounts: normalize
MyApp.Accounts->>MyApp.Accounts: create_user
```
"""

  describe "generate/1" do
    test "creates a correct Mermaid sequence diagram from AST" do
      File.rm("sequence_diagram.md")

      PipeTrace.Trace.from_source_file("test/fixtures/fake_controller.ex", :create)
      |> Mermaid.generate()

      assert File.exists?("sequence_diagram.md")
      content = File.read!("sequence_diagram.md")
      assert content == @expected_diagram
    end

    test "generates diagram with single function call" do
      File.rm("sequence_diagram.md")
      
      Mermaid.generate(["MyApp.Utils.process"])
      
      assert File.exists?("sequence_diagram.md")
      content = File.read!("sequence_diagram.md")
      
      assert content =~ "participant MyAppWeb.FakeController"
      assert content =~ "participant MyApp.Utils"
      assert content =~ "MyAppWeb.FakeController->>MyApp.Utils: process"
    end

    test "generates diagram with multiple different modules" do
      File.rm("sequence_diagram.md")
      
      calls = [
        "MyApp.Users.validate",
        "MyApp.Accounts.create",
        "MyApp.Notifications.send"
      ]
      
      Mermaid.generate(calls)
      
      assert File.exists?("sequence_diagram.md")
      content = File.read!("sequence_diagram.md")
      
      assert content =~ "participant MyAppWeb.FakeController"
      assert content =~ "participant MyApp.Users"
      assert content =~ "participant MyApp.Accounts"
      assert content =~ "participant MyApp.Notifications"
      assert content =~ "MyAppWeb.FakeController->>MyApp.Users: validate"
      assert content =~ "MyApp.Users->>MyApp.Accounts: create"
      assert content =~ "MyApp.Accounts->>MyApp.Notifications: send"
    end

    test "handles empty list of calls" do
      File.rm("sequence_diagram.md")
      
      Mermaid.generate([])
      
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
      
      Mermaid.generate(calls)
      
      assert File.exists?("sequence_diagram.md")
      content = File.read!("sequence_diagram.md")
      
      assert content =~ "participant MyAppWeb.FakeController"
      assert content =~ "participant MyApp.Accounts"
      assert content =~ "MyAppWeb.FakeController->>MyApp.Accounts: normalize"
      assert content =~ "MyApp.Accounts->>MyApp.Accounts: create_user"
    end

    test "filters out non-module participants" do
      File.rm("sequence_diagram.md")
      
      calls = ["params", "MyApp.Utils.process", "result"]
      
      Mermaid.generate(calls)
      
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
      
      Mermaid.generate(calls)
      
      assert File.exists?("sequence_diagram.md")
      content = File.read!("sequence_diagram.md")
      
      assert content =~ "MyAppWeb.FakeController->>MyApp.Utils: process"
      assert content =~ "MyApp.Utils->>MyApp.Utils: validate"
    end

    test "creates proper Mermaid syntax" do
      File.rm("sequence_diagram.md")
      
      Mermaid.generate(["MyApp.Utils.process"])
      
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
