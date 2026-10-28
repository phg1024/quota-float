import Foundation
import Testing
@testable import QuotaKit

/// Exercises the subprocess exchange with small shell scripts standing in for the CLIs.
@Suite struct JSONLineSessionTests {
    func run(_ script: String, timeout: TimeInterval = 5) throws -> String {
        try exchangeJSONLines(executable: "/bin/sh", arguments: ["-c", script], first: ["id": 1], timeout: timeout,
                              service: "Test", unreachable: "unreachable") { message, send -> String? in
            if message["id"] as? Int == 1 { try send(["id": 2]); return nil }
            return message["answer"] as? String
        }
    }

    @Test func exchangesMessagesAndSkipsNoise() throws {
        let answer = try run(#"read a; echo 'not json'; printf '{"id":1}\n'; read b; printf '{"progress":true}\n{"answer":"ok"}\n'"#)
        #expect(answer == "ok")
    }

    @Test func handlesLinesSplitAcrossWrites() throws {
        let answer = try run(#"read a; printf '{"id":'; sleep 0.2; printf '1}\n'; read b; printf '{"answer":"split"}\n'"#)
        #expect(answer == "split")
    }

    @Test func reportsEndOfOutput() {
        #expect(throws: QuotaError("unreachable")) { try run("read a; exit 0") }
    }

    @Test func timesOutAndKillsStubbornProcess() {
        let start = Date()
        #expect(throws: QuotaError("Test didn’t respond within 1 s. Refresh to try again.")) {
            try run("trap '' TERM; read a; sleep 30", timeout: 1)
        }
        #expect(Date().timeIntervalSince(start) < 6)
    }
}
