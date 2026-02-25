import Foundation
@testable import Swarm
import Testing

@Suite("Duration Extensions")
struct DurationExtensionsTests {
    @Test("timeInterval converts fractional seconds")
    func timeIntervalConvertsFractionalSeconds() {
        let duration: Duration = .seconds(1) + .milliseconds(250)
        let interval = duration.timeInterval
        #expect(abs(interval - 1.25) < 0.000_001)
    }

    @Test("timeInterval returns infinity for very large durations")
    func timeIntervalReturnsInfinityForLargeDurations() {
        let duration = Duration.seconds(Int64(1) << 53)
        let interval = duration.timeInterval
        #expect(interval == .infinity)
    }
}
