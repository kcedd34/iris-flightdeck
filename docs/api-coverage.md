# Cobertura de endpoints — SysAdmin API v2 por domínio do FlightDeck

Gerado de `docs/sysadmin-api-v2.json` (OpenAPI 3.0.0, base `/api/admin`).
**273 operações oficiais, todas atribuídas a um domínio.** Nenhuma operação fica fora de escopo.

O privilégio entre parênteses é declarado pela própria API e alimenta o mapa de capacidades da sessão (RN-FD-02), derivado da especificação e nunca codificado à mão.

| Domínio | Operações oficiais | Trabalho próprio adicional |
|---|---|---|
| 0. Sessão | 5 | Fallback de autenticação para instância anterior a 2026.2 |
| 1. Web apps e APIs | 8 | Explorador REST sobre `/api/mgmnt/` |
| 2. Permissões | 31 | Privilégio efetivo, grafo, análise de impacto |
| 3. Segurança e segredos | 89 | Cálculo de validade e alertas de vencimento |
| 4. Tarefas | 24 | Histórico compacto, correlação com logs |
| 5. Sistema operacional | 102 | Instrumentos em canvas, janela deslizante |
| 6. Logs | 14 | **`messages.log`, alertas, log de interoperabilidade, normalização** |
| **Total** | **273** | |

---

## 0. Sessão — 5 operações oficiais

Autenticação da API. `/login`, `/logout`, `/refresh` e `/revoke` exigem IRIS 2026.2 ou superior. `/info` é a sonda de versão, edição e privilégios do usuário.

> **Verificado em 2026-09-17** (`verification/`):
> - **Piso de versão.** A SysAdmin API **v2** só existe a partir do IRIS **2026.2**. As tags `latest` das imagens Community (`intersystemsdc/iris-community` 2026.1.0.234.1 e `intersystemsdc/irishealth-community` 2026.1.0.235.2) expõem apenas a v1 (`apiVersion: 1`, `/v2/*` → 404). O FlightDeck fixa as tags `2026.2-zpm` (2026.2.0.221.0).
> - **Corpo do `/login`.** O endpoint aceita `{"user", "password"}`. O `required: ["username", ...]` do spec está errado: `username` retorna 401.
> - **Privilégio declarado × comportamento real.** `GET /v2/database-dirs` retorna 403 para um usuário só com `%Admin_Operate:U`, embora o spec declare Manage **ou** Operate. `GET /v2/security/ldap/configurations` retorna 500 (`<INVALID OREF>`) para o mesmo usuário.
> - **Recursos.** `PUT /v2/security/resource` não aceita `PublicPermission` vazio.

### `general` (5)

| Método | Caminho | Privilégio | Resumo |
|---|---|---|---|
| GET | `/info` | - | Retrieve info about the server, API, and logged in user. Callable if the user has at least one of the %Admin privileges |
| POST | `/login` | - | Authenticate user and receive JWT tokens. Available starting in IRIS 2026.2 |
| POST | `/logout` | - | Logout and invalidate refresh token. Available starting in IRIS 2026.2 |
| POST | `/refresh` | - | Refresh access token. Available starting in IRIS 2026.2 |
| POST | `/revoke` | - | Revoke an access token. Available starting in IRIS 2026.2 |

---

## 1. Web apps e APIs — 8 operações oficiais

Cobertura oficial completa. O explorador de APIs REST do UC04 **não** é coberto por esta API e continua sobre `/api/mgmnt/` e `%REST.API`.

### `/v2/web-app` (8)

| Método | Caminho | Privilégio | Resumo |
|---|---|---|---|
| DELETE | `/v2/web-app` | %Admin_Secure:U | Delete a web application |
| GET | `/v2/web-app` | %Admin_Secure:U | View details of a web application |
| PUT | `/v2/web-app` | %Admin_Secure:U | Create/Edit a web application |
| DELETE | `/v2/web-app/pct-access` | %Admin_Secure:U | Delete a percent class access configuration |
| GET | `/v2/web-app/pct-access` | %Admin_Secure:U | View details of a percent class access configuration |
| PUT | `/v2/web-app/pct-access` | %Admin_Secure:U | Create/Edit a percent class access configuration |
| GET | `/v2/web-app/pct-accesses` | %Admin_Secure:U | View a list of percent class access configurations |
| GET | `/v2/web-apps` | %Admin_Secure:U | View a list of web applications |

---

## 2. Permissões — 31 operações oficiais

Base do grafo de permissões, do privilégio efetivo e da análise de impacto.

### `/v2/security` (31)

| Método | Caminho | Privilégio | Resumo |
|---|---|---|---|
| DELETE | `/v2/security/privileged-routine` | %Admin_Secure:U | Delete a privileged routine application |
| GET | `/v2/security/privileged-routine` | %Admin_Secure:U | View details of a privileged routine application |
| PUT | `/v2/security/privileged-routine` | %Admin_Secure:U | Create/Edit a privileged routine application |
| GET | `/v2/security/privileged-routines` | %Admin_Secure:U | View a list of privileged routine applications |
| DELETE | `/v2/security/resource` | %Admin_Secure:U | Delete a resource |
| GET | `/v2/security/resource` | %Admin_Secure:U | View details of a resource |
| PUT | `/v2/security/resource` | %Admin_Secure:U | Create/edit a resource |
| GET | `/v2/security/resources` | %Admin_Secure:U | View a list of resources |
| DELETE | `/v2/security/role` | %Admin_Secure:U | Delete a role |
| GET | `/v2/security/role` | %Admin_Secure:U | View details of a role |
| PUT | `/v2/security/role` | %Admin_Secure:U | Create/edit a role |
| GET | `/v2/security/role/owners` | %Admin_Secure:U | View the users and owners who hold a role, including as an escalation role |
| GET | `/v2/security/roles` | %Admin_Secure:U | View a list of roles |
| GET | `/v2/security/service` | %Admin_Secure:U | View details of a service |
| PUT | `/v2/security/service` | %Admin_Secure:U | This can be used to modify a system-defined service, but cannot be used to create a new service. |
| GET | `/v2/security/services` | %Admin_Secure:U | View a list of services, like %Service_Bindings |
| POST | `/v2/security/sql-admin-privilege/grant` | %Admin_Secure:U | Grant a SQL admin privilege |
| POST | `/v2/security/sql-admin-privilege/revoke` | %Admin_Secure:U | Revoke a SQL admin privilege |
| GET | `/v2/security/sql-admin-privileges` | %Admin_Secure:U | View a list of SQL admin privileges (like "%ALTER_TABLE") held by a certain role or user in a certain namespace |
| POST | `/v2/security/sql-column-privilege/grant` | %Admin_Secure:U | Grant a SQL column privilege |
| POST | `/v2/security/sql-column-privilege/revoke` | %Admin_Secure:U | Revoke a SQL column privilege |
| GET | `/v2/security/sql-column-privileges` | %Admin_Secure:U | View a list of SQL column privileges (like INSERT on column ID) held by a specified grantee on a specified object in a specified namespace |
| POST | `/v2/security/sql-privilege/grant` | %Admin_Secure:U | Grant a SQL privilege |
| POST | `/v2/security/sql-privilege/revoke` | %Admin_Secure:U | Revoke a SQL privilege |
| GET | `/v2/security/sql-privileges` | %Admin_Secure:U | View a list of SQL privileges (like whether a certain user can INSERT rows on a certain table in a certain namespace) |
| DELETE | `/v2/security/user` | %Admin_Secure:U | Delete a user |
| GET | `/v2/security/user` | %Admin_Secure:U | View details of a user |
| POST | `/v2/security/user` | %Admin_Secure:U | Create a new user (with a password) |
| PUT | `/v2/security/user` | %Admin_Secure:U | Edit a user. Use the POST api to create |
| POST | `/v2/security/user/password` | %Admin_Secure:U | Change a user's password |
| GET | `/v2/security/users` | %Admin_Secure:U | View a list of users |

---

## 3. Segurança e segredos — 89 operações oficiais

O maior domínio da API. O "etc" do enunciado é lido como cobertura integral: TLS, X.509, OAuth 2.0 nos três papéis, wallet, criptografia, LDAP, MFT, auditoria (configuração), superserver, delegated.

### `/v2/security` (82)

| Método | Caminho | Privilégio | Resumo |
|---|---|---|---|
| GET | `/v2/security/audit/enabled` | %Admin_Secure:U | See if auditing is enabled |
| PUT | `/v2/security/audit/enabled` | %Admin_Secure:U | Enable or disable auditing |
| POST | `/v2/security/audit/event/clear-count` | %Admin_Secure:U | Clear the count of an audit event |
| POST | `/v2/security/audit/record/copy` | %Admin_Secure:U | Copy audit records to another namespace |
| POST | `/v2/security/audit/record/purge` | %Admin_Secure:U | Purge all audit records older than a certain date (or all records regardless of date) |
| POST | `/v2/security/audit/records` | %Admin_Secure:U | List audit records, optionally filtering by time, event, username, etc... |
| GET | `/v2/security/encryption/data-element-keys` | %Admin_Secure:U | List keys activated for data element encryption |
| POST | `/v2/security/encryption/file` | %Admin_Secure:U | Create a new encryption key |
| POST | `/v2/security/encryption/file/activate` | %Admin_Secure:U | Activate Encryption key file |
| DELETE | `/v2/security/encryption/file/admin` | %Admin_Secure:U | Remove admin from key file |
| POST | `/v2/security/encryption/file/admin` | %Admin_Secure:U | Add an admin to an encryption key file |
| GET | `/v2/security/encryption/file/admins` | %Admin_Secure:U | List all admins in an encryption key file |
| DELETE | `/v2/security/encryption/file/key` | %Admin_Secure:U | Remove encryption key from a file |
| POST | `/v2/security/encryption/file/key` | %Admin_Secure:U | Add a new encryption key to a file |
| GET | `/v2/security/encryption/file/keys` | %Admin_Secure:U | List encryption keys in a file |
| POST | `/v2/security/encryption/key/deactivate` | %Admin_Secure:U | Deactivate an encryption key |
| GET | `/v2/security/encryption/keys` | %Admin_Secure:U | List activated encryption keys |
| GET | `/v2/security/encryption/settings` | %Admin_Secure:U | View encryption settings (startup settings and default encryption keys) |
| PUT | `/v2/security/encryption/settings` | %Admin_Secure:U | Update encryption startup settings |
| DELETE | `/v2/security/ldap/configuration` | %Admin_Secure:U | Delete an LDAP configuration |
| GET | `/v2/security/ldap/configuration` | %Admin_Operate:U or %Admin_Secure:U | View details of an LDAP configuration |
| PUT | `/v2/security/ldap/configuration` | %Admin_Secure:U | Create/Edit an LDAP configuration |
| POST | `/v2/security/ldap/configuration/search-password` | %Admin_Secure:U | Change or clear the search password for an LDAP configuration |
| GET | `/v2/security/ldap/configurations` | %Admin_Operate:U or %Admin_Secure:U | View a list of LDAP configurations |
| POST | `/v2/security/ldap/test` | %Admin_Secure:U | Test an LDAP login |
| DELETE | `/v2/security/mft/connection` | %Admin_Secure:U | Delete an MFT connection |
| GET | `/v2/security/mft/connection` | %Admin_Secure:U | View details of an MFT connection |
| PUT | `/v2/security/mft/connection` | %Admin_Secure:U | Create/edit an MFT connection |
| GET | `/v2/security/mft/connection/auth-code-url` | %Admin_Secure:U | Get an authorization code url for a given scope and redirect URL |
| DELETE | `/v2/security/mft/connection/token` | %Admin_Secure:U | Revoke the token associated with this connection |
| GET | `/v2/security/mft/connections` | %Admin_Secure:U | View a list of MFT connections |
| DELETE | `/v2/security/oauth2/client/client-configuration` | %Admin_OAuth2_Client:U | Delete an OAuth2 client configuration (Class OAuth2.OAuth2Client) |
| GET | `/v2/security/oauth2/client/client-configuration` | %Admin_OAuth2_Client:U | View details of an OAuth2 client configuration (Class OAuth2.OAuth2Client) |
| PUT | `/v2/security/oauth2/client/client-configuration` | %Admin_OAuth2_Client:U | Create/edit an OAuth2 client configuration (Class OAuth2.OAuth2Client) |
| POST | `/v2/security/oauth2/client/client-configuration/register-client` | %Admin_OAuth2_Client:U | Register an OAuth2 client configuration |
| POST | `/v2/security/oauth2/client/client-configuration/rotate-keys` | %Admin_OAuth2_Client:U | Rotate keys for an OAuth2 client configuration |
| POST | `/v2/security/oauth2/client/client-configuration/secrets` | %Admin_OAuth2_Client:U | Change the ClientPassword, ClientSecret, or registration_access_token of a client configuration |
| GET | `/v2/security/oauth2/client/client-configurations` | %Admin_OAuth2_Client:U | List client configurations for an authorization server |
| DELETE | `/v2/security/oauth2/client/server-definition` | %Admin_OAuth2_Client:U | Delete an OAuth2 server definition |
| GET | `/v2/security/oauth2/client/server-definition` | %Admin_OAuth2_Client:U | View details of an OAuth2 server definition |
| POST | `/v2/security/oauth2/client/server-definition` | %Admin_OAuth2_Client:U | Create an OAuth2 server definition |
| PUT | `/v2/security/oauth2/client/server-definition` | %Admin_OAuth2_Client:U | Edit an OAuth2 server definition. Use the POST Api to create |
| POST | `/v2/security/oauth2/client/server-definition/initial-access-token` | %Admin_OAuth2_Client:U | Update the InitialAccessToken associated with an OAuth2 Server Definition |
| GET | `/v2/security/oauth2/client/server-definitions` | %Admin_OAuth2_Client:U | View a list of OAuth2 auth servers this system is configured to use as a client |
| DELETE | `/v2/security/oauth2/resource-server` | %Admin_Secure:U | Delete an OAuth2 resource server |
| GET | `/v2/security/oauth2/resource-server` | %Admin_Secure:U | View details of an OAuth2 resource server |
| PUT | `/v2/security/oauth2/resource-server` | %Admin_Secure:U | Create/Edit an OAuth2 resource server |
| DELETE | `/v2/security/oauth2/resource-server/mapping` | %Admin_Secure:U | Delete an OAuth2 resource server mapping |
| GET | `/v2/security/oauth2/resource-server/mapping` | %Admin_Secure:U | View details of an OAuth2 resource server mapping |
| PUT | `/v2/security/oauth2/resource-server/mapping` | %Admin_Secure:U | Create/Edit an OAuth2 Resource server mapping |
| GET | `/v2/security/oauth2/resource-server/mappings` | %Admin_Secure:U | View a list of OAuth2 resource server mappings |
| POST | `/v2/security/oauth2/resource-server/secret` | %Admin_Secure:U | Change the client secret used for introspection with the Authorization server |
| GET | `/v2/security/oauth2/resource-servers` | %Admin_Secure:U | View a list of resource servers |
| POST | `/v2/security/oauth2/revoke` | %Admin_OAuth2_Registration:U | Revoke tokens for the specified user |
| DELETE | `/v2/security/oauth2/server` | %Admin_OAuth2_Server:U | Stop this instance acting as an OAuth2 Authorization Server |
| GET | `/v2/security/oauth2/server` | %Admin_OAuth2_Server:U | View details of how the instance is configured to act as an OAuth2 Authorization Server |
| PUT | `/v2/security/oauth2/server` | %Admin_OAuth2_Server:U | Edit details of how the instance is configured to act as an OAuth2 Authorization Server |
| DELETE | `/v2/security/oauth2/server/client` | %Admin_OAuth2_Registration:U | Delete an OAuth2 client (class OAuth2.Server.Client) |
| GET | `/v2/security/oauth2/server/client` | %Admin_OAuth2_Registration:U | View details of an OAuth2 client (Class OAuth2.Server.Client) |
| POST | `/v2/security/oauth2/server/client` | %Admin_OAuth2_Registration:U | Create an OAuth2 client |
| PUT | `/v2/security/oauth2/server/client` | %Admin_OAuth2_Registration:U | Edit details of an OAuth2 client (Class OAuth2.Server.Client). Use the POST api to create a client |
| POST | `/v2/security/oauth2/server/client/secret` | %Admin_OAuth2_Registration:U | Change the ClientSecret |
| GET | `/v2/security/oauth2/server/clients` | %Admin_OAuth2_Registration:U | View a list of clients for this instance acting as an OAuth2 auth server |
| POST | `/v2/security/oauth2/server/password` | %Admin_OAuth2_Server:U | Change the private key password associated with the X509 credentials |
| DELETE | `/v2/security/ssl-configuration` | %Admin_Secure:U | Delete an SSL configuration |
| GET | `/v2/security/ssl-configuration` | %Admin_Secure:U | View details of an SSL configuration |
| PUT | `/v2/security/ssl-configuration` | %Admin_Secure:U | Create/edit an SSL Configuration |
| POST | `/v2/security/ssl-configuration/test` | %Admin_Secure:U | Test an SSL configuration |
| GET | `/v2/security/ssl-configurations` | %Admin_Secure:U | View SSL configurations |
| DELETE | `/v2/security/superserver` | %Admin_Secure:U | Delete a superserver |
| GET | `/v2/security/superserver` | %Admin_Secure:U | View details of a superserver |
| PUT | `/v2/security/superserver` | %Admin_Secure:U | Create/edit a superserver |
| GET | `/v2/security/superservers` | %Admin_Secure:U | View a list of superservers |
| GET | `/v2/security/web-auth` | %Admin_Secure:U | View system-wide web authentication settings |
| PUT | `/v2/security/web-auth` | %Admin_Secure:U | Modify system-wide web authentication settings |
| POST | `/v2/security/web-auth/smtp-password` | %Admin_Secure:U | Change the SMTP password used for 2FA |
| DELETE | `/v2/security/x509-credential` | %Admin_Secure:U | Delete an X509 credential |
| GET | `/v2/security/x509-credential` | %Admin_Secure:U | View details of an X509 credential configuration |
| POST | `/v2/security/x509-credential` | %Admin_Secure:U | Create an X509 credential, potentially with a private key password |
| PUT | `/v2/security/x509-credential` | %Admin_Secure:U | Edit an X509 credential. Use the POST api to create |
| GET | `/v2/security/x509-credential/certificate` | %Admin_Secure:U | View details (e.g. Serial Number, SubjectDN) of the certificate pointed to by an X509 credential configuration |
| GET | `/v2/security/x509-credentials` | %Admin_Secure:U | View a list of X509 credentials |

### `/v2/wallet` (7)

| Método | Caminho | Privilégio | Resumo |
|---|---|---|---|
| DELETE | `/v2/wallet/collection` | %Admin_Wallet:U | Delete a Wallet collection |
| GET | `/v2/wallet/collection` | %Admin_Wallet:U | View details of a wallet collection |
| PUT | `/v2/wallet/collection` | %Admin_Wallet:U | Create/Edit a wallet collection |
| GET | `/v2/wallet/collections` | %Admin_Wallet:U | View a list of wallet collections |
| DELETE | `/v2/wallet/secret` | %Admin_Wallet:U | Delete a wallet secret |
| PUT | `/v2/wallet/secret` | %Admin_Wallet:U | Create/Edit a wallet secret |
| GET | `/v2/wallet/secrets` | %Admin_Wallet:U | View a list of names and types of secrets in a wallet collection |

---

## 4. Tarefas — 24 operações oficiais

Inclui categorias do Work Queue Manager e o ciclo de resultados assíncronos, que também serve o instrumento de disco do domínio 5.

### `/v2/async-result` (5)

| Método | Caminho | Privilégio | Resumo |
|---|---|---|---|
| GET | `/v2/async-result` | %Admin_Operate:U | View the status of an async task. Cannot view tasks initiated by other users. |
| POST | `/v2/async-result/cancel` | %Admin_Operate:U | Cancel an async task. Cannot cancel tasks initiated by other users. |
| POST | `/v2/async-result/pause` | %Admin_Operate:U | Pause an async task. Cannot pause tasks initiated by other users. |
| POST | `/v2/async-result/resume` | %Admin_Operate:U | Resume an async task. Cannot resume tasks initiated by other users. |
| GET | `/v2/async-results` | %Admin_Operate:U | View async tasks. Will not include tasks initiated by other users. |

### `/v2/task` (15)

| Método | Caminho | Privilégio | Resumo |
|---|---|---|---|
| DELETE | `/v2/task` | %Admin_Operate:U or %Admin_Task:U | Delete a task |
| GET | `/v2/task` | %Admin_Operate:U or %Admin_Task:U | View details of a task |
| POST | `/v2/task` | %Admin_Operate:U or %Admin_Task:U | Create a new task definition |
| PUT | `/v2/task` | %Admin_Operate:U or %Admin_Task:U | Create/Edit a task |
| GET | `/v2/task/history` | %Admin_Operate:U | View a history of previously run tasks |
| GET | `/v2/task/info` | %Admin_Operate:U | View non-configurable info about a task, such as when it last finished or last started |
| GET | `/v2/task/manager` | %Admin_Operate:U or %Admin_Task:U | View the status of the task manager |
| POST | `/v2/task/manager/resume` | %Admin_Operate:U or %Admin_Task:U | Resume the task manager |
| POST | `/v2/task/manager/run` | %Admin_Operate:U or %Admin_Task:U | Run the task manager |
| POST | `/v2/task/manager/suspend` | %Admin_Operate:U or %Admin_Task:U | Suspend the task manager |
| POST | `/v2/task/resume` | %Admin_Task:U | Resume a task |
| POST | `/v2/task/run` | %Admin_Task:U | Run a task right now or at a specified time |
| POST | `/v2/task/suspend` | %Admin_Task:U | Suspend a task |
| GET | `/v2/task/upcoming` | %Admin_Operate:U | View a list of upcoming tasks and when they are scheduled to run |
| GET | `/v2/tasks` | %Admin_Operate:U or %Admin_Task:U | View a list of tasks |

### `/v2/wqm-category` (4)

| Método | Caminho | Privilégio | Resumo |
|---|---|---|---|
| GET | `/v2/wqm-categories` | %Admin_Manage:U | View a list of WQM categories |
| DELETE | `/v2/wqm-category` | %Admin_Manage:U | Delete a WQM category |
| GET | `/v2/wqm-category` | %Admin_Manage:U | View details of a WQM category |
| PUT | `/v2/wqm-category` | %Admin_Manage:U | Create/Edit a WQM category |

---

## 5. Sistema operacional — 102 operações oficiais

O "etc" do enunciado é lido como cobertura integral: processos, monitor, bancos, diretórios de banco, namespaces, dispositivos, licença, locks, sessões web, ECP, servidores de linguagem externa, DocDB e finalidades de acesso a arquivo.

### `/v2/database` (4)

| Método | Caminho | Privilégio | Resumo |
|---|---|---|---|
| DELETE | `/v2/database` | %Admin_Manage:U | Delete a database (Config.Databases) |
| GET | `/v2/database` | %Admin_Manage:U | View details of a database (Config.Databases) |
| PUT | `/v2/database` | %Admin_Manage:U | Edit/create a database (Config.Databases) |
| GET | `/v2/databases` | %Admin_Manage:U or %Admin_Operate:U | List databases (Config.Databases entries) |

### `/v2/database-dir` (15)

| Método | Caminho | Privilégio | Resumo |
|---|---|---|---|
| DELETE | `/v2/database-dir` | %Admin_Manage:U | Delete a local database |
| GET | `/v2/database-dir` | %Admin_Manage:U or %Admin_Operate:U | View details of a local database |
| POST | `/v2/database-dir` | %Admin_Manage:U | Create a local database |
| PUT | `/v2/database-dir` | %Admin_Manage:U | Edit a local database. Use the POST API to create a database |
| POST | `/v2/database-dir/compact` | %Admin_Operate:U | Compact a local database |
| POST | `/v2/database-dir/defragment` | %Admin_Operate:U | Defragment a local database |
| POST | `/v2/database-dir/dismount` | %Admin_Operate:U | Dismount a local database |
| POST | `/v2/database-dir/expand-volume` | %Admin_Manage:U | Expand the database into a new volume |
| POST | `/v2/database-dir/info` | %Admin_Manage:U or %Admin_Operate:U | View a variety of non-configurable info, such as block size and available free space |
| POST | `/v2/database-dir/integrity-check` | %Admin_Operate:U | Run an integrity check on a local database |
| POST | `/v2/database-dir/modify-size` | %Admin_Manage:U | Expand the size of a database |
| POST | `/v2/database-dir/mount` | %Admin_Operate:U | Mount a local database |
| POST | `/v2/database-dir/truncate` | %Admin_Operate:U | Truncate a local database |
| GET | `/v2/database-dir/volumes` | %Admin_Manage:U | View the list of volumes associated with a local database |
| GET | `/v2/database-dirs` | %Admin_Manage:U or %Admin_Operate:U | List local databases |

### `/v2/device` (10)

| Método | Caminho | Privilégio | Resumo |
|---|---|---|---|
| DELETE | `/v2/device` | %Admin_Manage:U | Delete a device |
| GET | `/v2/device` | %Admin_Manage:U | View details of a device |
| PUT | `/v2/device` | %Admin_Manage:U | Create/Edit a device |
| GET | `/v2/device/settings` | %Admin_Manage:U | View settings for telnet, device IO |
| PUT | `/v2/device/settings` | %Admin_Manage:U | Update settings for telnet, device IO |
| DELETE | `/v2/device/subtype` | %Admin_Manage:U | Delete a device subtype |
| GET | `/v2/device/subtype` | %Admin_Manage:U | View details of a device subtype |
| PUT | `/v2/device/subtype` | %Admin_Manage:U | Create/Edit a device subtype |
| GET | `/v2/device/subtypes` | %Admin_Manage:U | View a list of device subtypes |
| GET | `/v2/devices` | %Admin_Manage:U | View a list of devices |

### `/v2/doc-db` (4)

| Método | Caminho | Privilégio | Resumo |
|---|---|---|---|
| DELETE | `/v2/doc-db` | %Admin_Secure:U | Delete a doc db application |
| GET | `/v2/doc-db` | %Admin_Secure:U | View details of a doc db application |
| PUT | `/v2/doc-db` | %Admin_Secure:U | Create/Edit a doc db application |
| GET | `/v2/doc-dbs` | %Admin_Secure:U | View a list of doc db applications |

### `/v2/ecp` (13)

| Método | Caminho | Privilégio | Resumo |
|---|---|---|---|
| DELETE | `/v2/ecp/application-server-ssl-connection` | %Admin_Manage:U | Remove an entry from the ECP SSL authorized list |
| POST | `/v2/ecp/application-server-ssl-connection/authorize` | %Admin_Manage:U | Authorize an incoming ECP connection pending for SSL authorization |
| POST | `/v2/ecp/application-server-ssl-connection/reject` | %Admin_Manage:U | Reject an incoming ECP connection pending for SSL authorization |
| GET | `/v2/ecp/application-server-ssl-connections` | %Admin_Manage:U | View a list of pending incoming SSL connections and authorized incoming ECP connections |
| GET | `/v2/ecp/application-servers` | %Admin_Manage:U | View a list of ECP clients |
| DELETE | `/v2/ecp/data-server` | %Admin_Manage:U | Delete an ECP data server |
| GET | `/v2/ecp/data-server` | %Admin_Manage:U | View details of an ECP data server |
| PUT | `/v2/ecp/data-server` | %Admin_Manage:U | Create/Edit an ECP data server |
| POST | `/v2/ecp/data-server/action` | %Admin_Manage:U | Change the status of a connection with a data server |
| GET | `/v2/ecp/data-server/databases` | %Admin_Manage:U | View a list of databases available on an ECP data server |
| GET | `/v2/ecp/data-servers` | %Admin_Manage:U | View a list of ECP data servers |
| GET | `/v2/ecp/settings` | %Admin_Manage:U | View ECP settings |
| PUT | `/v2/ecp/settings` | %Admin_Manage:U | Update ECP settings |

### `/v2/ext-lang-server` (7)

| Método | Caminho | Privilégio | Resumo |
|---|---|---|---|
| DELETE | `/v2/ext-lang-server` | %Admin_ExternalLanguageServerEdit:U | Delete an external language server |
| GET | `/v2/ext-lang-server` | %Admin_ExternalLanguageServerEdit:U | View details of an external language server |
| PUT | `/v2/ext-lang-server` | %Admin_ExternalLanguageServerEdit:U | Create/edit an external language server |
| GET | `/v2/ext-lang-server/activity` | %Admin_ExternalLanguageServerEdit:U | View a history of activity related to an external language server, and whether or not it is currently running |
| POST | `/v2/ext-lang-server/start` | %Admin_ExternalLanguageServerEdit:U | Start an external language server |
| POST | `/v2/ext-lang-server/stop` | %Admin_ExternalLanguageServerEdit:U | Stop an external language server |
| GET | `/v2/ext-lang-servers` | %Admin_ExternalLanguageServerEdit:U | View a list of external language servers |

### `/v2/fs-access-purpose` (7)

| Método | Caminho | Privilégio | Resumo |
|---|---|---|---|
| DELETE | `/v2/fs-access-purpose` | %Admin_FileSystemAccess:U | Delete a file system access purpose |
| GET | `/v2/fs-access-purpose` | %Admin_FileSystemAccess:U | Check if a file system access purpose exists and whether it is restricted |
| PUT | `/v2/fs-access-purpose` | %Admin_FileSystemAccess:U | Create or edit a file system access purpose |
| DELETE | `/v2/fs-access-purpose/path` | %Admin_FileSystemAccess:U | Delete a root file path associated with a given access purpose |
| PUT | `/v2/fs-access-purpose/path` | %Admin_FileSystemAccess:U | Create a root file path with access allowed for a purpose |
| GET | `/v2/fs-access-purpose/paths` | %Admin_FileSystemAccess:U | List paths for a given file system access purpose |
| GET | `/v2/fs-access-purposes` | %Admin_FileSystemAccess:U | List file system access purposes |

### `/v2/license` (7)

| Método | Caminho | Privilégio | Resumo |
|---|---|---|---|
| GET | `/v2/license/key` | %Admin_Manage:U | View license key info |
| PUT | `/v2/license/key` | %Admin_Manage:U | Activate a license key |
| POST | `/v2/license/key/validate` | %Admin_Manage:U | Validate a license key |
| DELETE | `/v2/license/server` | %Admin_Manage:U | Delete a license server |
| GET | `/v2/license/server` | %Admin_Manage:U | View details of a license server |
| PUT | `/v2/license/server` | %Admin_Manage:U | Edit/Create a license server |
| GET | `/v2/license/servers` | %Admin_Manage:U | View a list of license servers |

### `/v2/lock` (2)

| Método | Caminho | Privilégio | Resumo |
|---|---|---|---|
| DELETE | `/v2/lock` | %Admin_Operate:U | Delete a lock |
| GET | `/v2/locks` | %Admin_Operate:U | View a list of locks |

### `/v2/monitor` (7)

| Método | Caminho | Privilégio | Resumo |
|---|---|---|---|
| GET | `/v2/monitor/dashboard/ecp` | %Admin_Operate:U | View dashboard stats regarding ECP |
| GET | `/v2/monitor/dashboard/globals-and-routines` | %Admin_Operate:U | View dashboard stats regarding globals and routines |
| GET | `/v2/monitor/dashboard/main` | %Admin_Operate:U | View dashboard stats |
| GET | `/v2/monitor/dashboard/system-resources` | %Admin_Operate:U | View dashboard stats regarding system resources |
| GET | `/v2/monitor/license-usage` | %Admin_Operate:U | View license usage info |
| GET | `/v2/monitor/system-usage` | %Admin_Operate:U | View system usage stats |
| GET | `/v2/monitor/system-usage/shared-memory` | %Admin_Operate:U | View system usage stats regarding shared memory |

### `/v2/namespace` (18)

| Método | Caminho | Privilégio | Resumo |
|---|---|---|---|
| DELETE | `/v2/namespace` | %Admin_Manage:U | Delete a namespace and any associated web apps |
| GET | `/v2/namespace` | %Admin_Manage:U | View details of a namespace |
| PUT | `/v2/namespace` | %Admin_Manage:U | Create/Edit a namespace |
| POST | `/v2/namespace/copy-mappings` | %Admin_Manage:U | Copy mappings from one namespace to another. Recommended to use this right after creating a namespace |
| POST | `/v2/namespace/enable-interop` | %Admin_Manage:U | Enable interop in a namespace. Recommended to use this right after creating a namespace |
| DELETE | `/v2/namespace/global-mapping` | %Admin_Manage:U | Delete a global mapping |
| GET | `/v2/namespace/global-mapping` | %Admin_Manage:U | View details of a global mapping |
| PUT | `/v2/namespace/global-mapping` | %Admin_Manage:U | Create/edit a global mapping |
| GET | `/v2/namespace/global-mappings` | %Admin_Manage:U | View a list of global mappings |
| DELETE | `/v2/namespace/package-mapping` | %Admin_Manage:U | Delete a package mapping |
| GET | `/v2/namespace/package-mapping` | %Admin_Manage:U | View details of a package mapping |
| PUT | `/v2/namespace/package-mapping` | %Admin_Manage:U | Create/Edit a package mapping |
| GET | `/v2/namespace/package-mappings` | %Admin_Manage:U | View a list of package mappings |
| DELETE | `/v2/namespace/routine-mapping` | %Admin_Manage:U | Delete a routine mapping |
| GET | `/v2/namespace/routine-mapping` | %Admin_Manage:U | View details of a routine mapping |
| PUT | `/v2/namespace/routine-mapping` | %Admin_Manage:U | Create/edit a routine mapping |
| GET | `/v2/namespace/routine-mappings` | %Admin_Manage:U | View a list of routine mappings |
| GET | `/v2/namespaces` | %Admin_Manage:U | View a list of namespaces |

### `/v2/process` (6)

| Método | Caminho | Privilégio | Resumo |
|---|---|---|---|
| GET | `/v2/process` | %Admin_Operate:U | View details of a process |
| POST | `/v2/process/broadcast` | %Admin_Operate:U | Broadcast a message to all processes |
| POST | `/v2/process/resume` | %Admin_Operate:U | Resume a process |
| POST | `/v2/process/suspend` | %Admin_Operate:U | Suspend a process |
| POST | `/v2/process/terminate` | %Admin_Operate:U | Terminate a process |
| GET | `/v2/processes` | %Admin_Operate:U | View a list of processes |

### `/v2/web-session` (2)

| Método | Caminho | Privilégio | Resumo |
|---|---|---|---|
| DELETE | `/v2/web-session` | %Admin_Operate:U | Delete a web session |
| GET | `/v2/web-sessions` | %Admin_Operate:U | View a list of web sessions |

---

## 6. Logs — 14 operações oficiais

⚠️ A API oficial cobre apenas auditoria e journal. `messages.log`, alertas e o log de eventos de interoperabilidade são provedores nativos, trabalho próprio. Este é o único eixo obrigatório sem cobertura oficial.

### `/v2/journal` (9)

| Método | Caminho | Privilégio | Resumo |
|---|---|---|---|
| GET | `/v2/journal/file` | %Admin_Operate:U | View details of a journal file |
| POST | `/v2/journal/file/integrity-check` | %Admin_Operate:U | Run integrity check on journal file |
| GET | `/v2/journal/file/record` | %Admin_Operate:U | View details of a journal record. Must have READ permission on the corresponding database, if the record is associated with a database |
| POST | `/v2/journal/file/records` | %Admin_Operate:U | List journal records in a file. The result will exclude records related to databases which this user does not have read permission on |
| GET | `/v2/journal/files` | %Admin_Operate:U | List journal files |
| GET | `/v2/journal/settings` | %Admin_Manage:U or %Admin_Journal:U | View journal settings |
| PUT | `/v2/journal/settings` | %Admin_Manage:U or %Admin_Journal:U | Update miscellaneous journal settings |
| POST | `/v2/journal/switch-dir` | %Admin_Operate:U | Switch the journal directory |
| POST | `/v2/journal/switch-file` | %Admin_Operate:U | Switch the journal file |

### `/v2/security` (5)

| Método | Caminho | Privilégio | Resumo |
|---|---|---|---|
| DELETE | `/v2/security/audit/event` | %Admin_Secure:U | Delete an audit event configuration |
| GET | `/v2/security/audit/event` | %Admin_Secure:U | View the details of an audit event |
| PUT | `/v2/security/audit/event` | %Admin_Secure:U | Create or edit an audit event |
| GET | `/v2/security/audit/events` | %Admin_Secure:U | List audit event definitions |
| GET | `/v2/security/audit/record` | %Admin_Secure:U | View details of an audit record |
