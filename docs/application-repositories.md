# Application Repositories

Application source repositories belong under `repositorios/`. They are separate working trees and are not embedded as Git submodules in this infrastructure repository.

## Running Applications

Applications may run in either of these modes:

- **Host-run:** Start the application with its native development command. Connect to local services through `localhost` and their published ports.
- **Container-run:** Start the application with Docker Compose. Connect to local services through their Docker service names and internal ports.

The optional MySQL, PostgreSQL, and Redis extensions provide generic shared services, not application runtimes. Start them from the infrastructure repository when needed; keep application runtimes, dependency installation, web servers, and framework commands with the application. For multiple applications sharing a SQL server, create separate databases and users rather than sharing one application's schema.

Choose one mode per application instance to avoid port conflicts and duplicate consumers.

## Shared Docker Network

Container-run applications should join the same Docker network as the local service stack. This allows service discovery by Compose service name and avoids exposing internal traffic through host ports.

Host-run applications are outside that network. Their configuration must use the host-accessible endpoints documented in [Local Services](local-services.md).

## Repository Boundaries

Keep application code, dependency manifests, tests, and application-specific environment files in each repository. Keep shared service orchestration, local infrastructure configuration, and cross-repository operational documentation here.
