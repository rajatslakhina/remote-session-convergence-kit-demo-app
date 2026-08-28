import Foundation
import RemoteSessionConvergenceKit

/// The app's own scenario, compiled in here rather than shipped inside the package.
///
/// `RemoteSessionConvergenceKit` deliberately contains no sample session: what a demo
/// should show is an application decision, and an integrator adopting the package
/// should not have to strip out someone else's fixture data. So the console takes its
/// configuration as a parameter and this app owns it.
///
/// The numbers below are the interesting part of the demo, so they are argued for
/// rather than picked:
///
/// * **A hostile transport by default.** A perfect-network demo would show a screen
///   that converges and prove nothing, because the naive merger converges too. The
///   whole point is only visible under drop, reorder and coalescing.
/// * **A device advertising both absolute and relative volume.** That is what makes
///   the degrade path reachable: withdrawing absolute volume leaves something weaker
///   to fall back to, rather than a dead end.
/// * **A three-and-a-half minute track.** Long enough that the playhead extrapolates
///   visibly between pushes, short enough to reach the end while someone is watching.
/// * **36 ticks per burst.** Chosen by measurement, not taste. The hostile profile
///   coalesces runs of three and then drops ~35%, so 36 ticks generates 46 envelopes
///   and lands 13 on the device — enough for the delivery log to be worth reading and
///   for the property check to have real material. At 12 ticks only 5 survive, which
///   works but leaves the screen thin.
///
/// > These numbers are quoted in the README, so they are pinned by
/// > `testHostileDemoStreamNumbersAreStable` in the library's test suite, which runs
/// > this exact script, profile, seed and tick count. Change anything here and that
/// > test fails, which is the intended way to find out the README went stale.
enum DemoConfiguration {

    static let livingRoomSpeaker = ConvergenceConsoleConfiguration(
        script: SessionScript(
            device: MediaDeviceID("living-room-speaker"),
            capabilities: [.transport, .seek, .absoluteVolume, .relativeVolume, .skip],
            title: "Ashes of Orion",
            artist: "Kepler Field",
            duration: 214
        ),
        transport: .hostile,
        ticksPerBurst: 36,
        permutations: 96,
        seed: 0xC0FF_EE00_1234_5678,
        policy: StalenessPolicy(agingAfter: 4, staleAfter: 12, presumedLostAfter: 45)
    )
}
