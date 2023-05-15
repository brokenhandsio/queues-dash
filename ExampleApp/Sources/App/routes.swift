import Fluent
import Vapor

func routes(_ app: Application) throws {
    app.get { req async throws -> String in
        try await req.queue.dispatch(FooJob.self, Bar(message: "Hello, world!"))
        return "It works! Scheduled FooJob."
    }
}
