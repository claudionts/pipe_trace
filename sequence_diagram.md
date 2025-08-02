```mermaid
sequenceDiagram
participant MyAppWeb.FakeController
participant MyApp.Accounts
MyAppWeb.FakeController->>MyApp.Accounts: normalize
MyApp.Accounts->>MyApp.Accounts: create_user
```
