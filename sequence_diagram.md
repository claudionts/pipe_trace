```mermaid
sequenceDiagram
participant MyAppWeb.FakeController
participant MyApp.Utils
MyAppWeb.FakeController->>params: params
params->>MyApp.Utils: process
MyApp.Utils->>result: result
```
