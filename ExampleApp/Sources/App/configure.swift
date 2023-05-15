import NIOSSL
import Fluent
import FluentPostgresDriver
import Vapor
import QueuesFluentDriver
import QueuesDatabaseHooks

// configures your application
public func configure(_ app: Application) async throws {
    app.databases.use(.postgres(configuration: SQLPostgresConfiguration(
        hostname: Environment.get("DATABASE_HOST") ?? "localhost",
        port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? SQLPostgresConfiguration.ianaPortNumber,
        username: Environment.get("DATABASE_USERNAME") ?? "vapor_username",
        password: Environment.get("DATABASE_PASSWORD") ?? "vapor_password",
        database: Environment.get("DATABASE_NAME") ?? "vapor_database",
        tls: .prefer(try .init(configuration: .clientDefault)))
    ), as: .psql)

    app.migrations.add(JobMetadataMigrate())
    app.migrations.add(QueueDatabaseEntryMigration())

    try await app.autoMigrate()

    // register jobs
    app.queues.use(.fluent())
    app.queues.add(FooJob())

    app.queues.add(QueuesDatabaseNotificationHook.default(db: app.db))

    try app.queues.startInProcessJobs(on: .default)

    // register routes
    try routes(app)
}
