# Direct Upload Architecture

Direct upload is an optional application pattern. It is implemented by applications; the local infrastructure only provides the generic storage and messaging services it may use.

## Flow

1. An application authorizes an upload and creates a short-lived, scoped upload instruction for an S3-compatible storage service.
2. The client uploads the object directly to storage.
3. The client submits the resulting object reference to the application.
4. The application validates ownership, object metadata, size, and allowed key prefix before persisting a record.
5. If asynchronous work is needed, the application publishes a message to RabbitMQ.
6. A worker consumes the message, processes the object, writes derived objects, and publishes completion or failure state.

## Responsibilities

Applications must define their own authorization rules, key layout, retention policy, validation limits, message contracts, retry policy, and cleanup behavior. Workers must be idempotent because messages can be retried or delivered more than once.

## Security

- Grant upload instructions only the minimum object key, method, content type, size, and lifetime required.
- Never expose storage credentials to clients.
- Verify uploaded objects on the application side before making them available.
- Keep unconfirmed or failed uploads in a separate prefix and remove them on a scheduled basis.

## Local Development

Use MinIO as the S3-compatible storage implementation and RabbitMQ for asynchronous messaging. Configure endpoint and bucket settings through application environment variables.
