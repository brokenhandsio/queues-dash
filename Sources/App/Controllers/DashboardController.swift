//
//  File.swift
//
//
//  Created by Jimmy McDermott on 10/11/20.
//

import Foundation
import Vapor
import Fluent
import QueuesDatabaseHooks
import SQLKit

struct DashboardController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes.get(use: dashboard)
    }

    func dashboard(req: Request) async throws -> View {
        let hours = (try? req.query.get(Int.self, at: "hours")) ?? 1
        let currentJobs = try await QueueDatabaseEntry.getStatusOfCurrentJobs(db: req.db).get()
        let completedJobs = try await QueueDatabaseEntry.getCompletedJobsForTimePeriod(db: req.db, hours: hours)
            .get()
        let timing = try await QueueDatabaseEntry.getTimingDataForJobs(db: req.db, hours: hours).get()
        let (throughput, execution) = try await getGraphData(req: req).get()

        return try await req.view.render(
            "dashboard",
            DashboardViewContext(
                currentJobData: currentJobs,
                completedJobData: completedJobs,
                timingData: timing,
                hours: hours,
                throughputValues: throughput,
                executionTimeValues: execution
            )
        )
    }

    private func getGraphData(
        req: Request
    ) -> EventLoopFuture<(throughput: [DashboardViewContext.GraphData], execution: [DashboardViewContext.GraphData])> {
        let executionQuery: SQLQueryString = """
        SELECT
            avg(EXTRACT(EPOCH FROM ("completedAt" - "dequeuedAt"))) as "value",
            TO_CHAR("completedAt", 'HH:00') as "key"
        FROM
            _queue_job_completions
        WHERE
            "completedAt" IS NOT NULL
            AND "completedAt" >= NOW() - INTERVAL '24' HOUR
        GROUP BY
            TO_CHAR("completedAt", 'HH:00')
        """

        let throughputQuery: SQLQueryString = """
        SELECT
            count(*) * 1.0 as "value",
            TO_CHAR("completedAt", 'HH:00') as "key"
        FROM
            _queue_job_completions
        WHERE
            "completedAt" IS NOT NULL
            AND "completedAt" >= NOW() - INTERVAL '24' HOUR
        GROUP BY
            TO_CHAR("completedAt", 'HH:00')
        """

        guard let sqlDb = req.db as? SQLDatabase else {
            return req.eventLoop.future(error: Abort(.internalServerError))
        }
        return sqlDb
            .raw(executionQuery)
            .all(decoding: DashboardViewContext.GraphData.self)
            .and(sqlDb.raw(throughputQuery).all(decoding: DashboardViewContext.GraphData.self))
            .map { execution, throughput in
                return (throughput, execution)
            }
    }
}
