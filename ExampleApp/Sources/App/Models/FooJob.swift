import Vapor
import Queues

struct Bar: Codable {
    let message: String
}

struct FooJob: AsyncJob {
    typealias Payload = Bar

    func dequeue(_ context: QueueContext, _ payload: Bar) async throws {
        context.application.logger.info("\(payload.message)")
    }

    func error(_ context: QueueContext, _ error: Error, _ payload: Bar) async throws {
        context.application.logger.error("\(error)")
    }
}
