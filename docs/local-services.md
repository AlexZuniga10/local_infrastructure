# Local Services

This repository provides a local Docker environment for shared development services. Start the stack with Docker Compose before running applications that depend on it.

## Service Endpoints

| Service | Purpose | Local endpoint | Authentication |
| --- | --- | --- | --- |
| RabbitMQ | Message broker and management UI | `amqp://localhost:5672`, `http://localhost:15672` | `RABBITMQ_USERNAME` and `RABBITMQ_PASSWORD` from `.env` |
| MongoDB | Document database | `mongodb://localhost:27017` | `MONGODB_USERNAME` and `MONGODB_PASSWORD` from `.env` |
| Mongo Express | MongoDB administration UI | `http://localhost:8081` | `MONGO_EXPRESS_USERNAME` and `MONGO_EXPRESS_PASSWORD` from `.env` |
| MinIO | S3-compatible storage and console | `http://localhost:9000`, `http://localhost:9001` | `MINIO_ROOT_USER` and `MINIO_ROOT_PASSWORD` from `.env` |
| Mailpit | Local email capture and viewer | SMTP `localhost:1025`, `http://localhost:8025` | None |
| Portainer | Container administration UI | `http://localhost:9002`, `https://localhost:9443` | Create a local administrator on first access |

## Service Use

- Configure applications with environment variables; do not commit local connection values or credentials.
- Use service names and internal ports when an application runs on the shared Docker network.
- Use `localhost` and published ports when an application runs on the host.
- Treat all local data as disposable unless it is explicitly persisted through Docker volumes.
- The generated credentials belong only to local development. Do not print or share `.env` values.

Portainer stores its administrator account in its Docker volume. Resetting volumes removes this account and all other local service data.

## Operations

Use Docker Compose to start, stop, inspect, and refresh the local stack. Check container health and logs before diagnosing application-level connection failures.
