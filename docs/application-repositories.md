# Application Repositories

Application source repositories belong under `repositorios/`. They are separate working trees and are not embedded as Git submodules in this infrastructure repository.

## Running Applications

Applications may run in either of these modes:

- **Host-run:** Start the application with its native development command. Connect to local services through `localhost` and their published ports.
- **Container-run:** Start the application with Docker Compose. Connect to local services through their Docker service names and internal ports.

The optional MySQL, PostgreSQL, and Redis extensions provide generic shared services. On the `develop_php_8.3.6` branch, `enviroment/activate.sh` also selects an isolated PHP 8.3.6 CLI runtime for the current shell. Applications still own their dependency installation, web servers, framework commands, and PHP compatibility requirements. For multiple applications sharing a SQL server, create separate databases and users rather than sharing one application's schema.

For PHP and Laravel applications, follow the [local workflow, MVC, branch, and security rules](php-laravel-local-workflow.md) (Spanish). Check the application's locked Laravel version and PHP requirements before running Composer or Artisan. Laravel 8 is outside its official PHP range on this branch and is past its security support date; a successful local start is not a production readiness check.

Choose one mode per application instance to avoid port conflicts and duplicate consumers.

## Shared Docker Network

Container-run applications should join the same Docker network as the local service stack. This allows service discovery by Compose service name and avoids exposing internal traffic through host ports.

Host-run applications are outside that network. Their configuration must use the host-accessible endpoints documented in [Local Services](local-services.md).

## Repository Boundaries

Keep application code, dependency manifests, tests, and application-specific environment files in each repository. Keep shared service orchestration, local infrastructure configuration, and cross-repository operational documentation here.

Work in a task branch in each repository. Never commit directly to `main` or `develop`, and never open a PR targeting either branch. Review the active branch and the PR target before publishing. Each repository's approved integration branch determines where its PR goes.
