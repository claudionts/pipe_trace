```mermaid
sequenceDiagram
participant CustomApp.Web.UserController
participant CustomApp.Web.UserController
participant CustomApp.Accounts
participant CustomApp.AccountChangeset
participant CustomApp.Validators
CustomApp.Web.UserController->>CustomApp.Accounts: validate
CustomApp.Accounts-->>CustomApp.Web.UserController: validate response
CustomApp.Accounts->>CustomApp.AccountChangeset: changeset
CustomApp.AccountChangeset-->>CustomApp.Accounts: changeset response
CustomApp.AccountChangeset->>CustomApp.Validators: validate_email
CustomApp.Validators-->>CustomApp.AccountChangeset: validate_email response
CustomApp.AccountChangeset->>CustomApp.Validators: validate_password
CustomApp.Validators-->>CustomApp.AccountChangeset: validate_password response
CustomApp.Web.UserController->>CustomApp.Accounts: create
CustomApp.Accounts-->>CustomApp.Web.UserController: create response
```
