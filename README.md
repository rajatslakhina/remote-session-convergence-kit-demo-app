# RemoteSessionConvergenceKit — Demo App

**A merge strategy you can watch fail.**

This is a runnable iOS app around [`RemoteSessionConvergenceKit`](https://github.com/rajatslakhina/remote-session-convergence-kit). It simulates the transport a remote Now Playing session actually runs on — a push channel that **drops**, **reorders** and **coalesces** — feeds the survivors into the convergence engine, and then, on the same screen, runs the convergence properties live and shows you whether they hold.

The important control is one segmented picker:

| Strategy | What happens on screen |
|---|---|
| **Stamped LWW** | `PASS — 13 envelopes, 96 orderings agree` |
| **Naive overwrite** | `FAIL — 2 violation(s): commutativity, monotonicity`, with the counterexample printed |

Same envelopes. Same lossy transport. One merge rule apart.

Those two strings are exact. The default burst generates 46 envelopes and the hostile transport lands 13 of them — a 72% loss rate, which is what "best-effort, coalescing" actually means. Both figures are pinned by `testHostileDemoStreamNumbersAreStable` in the library's suite, so a stale README here is a failing test rather than something you have to notice.

## Why this matters

The naive strategy isn't a straw man — it's what a first-draft push handler does, and it's *correct* on an ordered transport. It stays correct right up until the first reordered delivery, and then it fails the way distributed bugs fail: no crash, no error, just two phones showing two different screens for one speaker and nobody able to reproduce it.

Being able to flip between the two, on real deliveries, in one tap, is the whole point of shipping this as an app rather than a paragraph.

## What's on screen

- **Now playing** — the converged session, with a freshness badge (`fresh` → `aging` → `stale` → `presumedLost`), an `extrapolated` badge when the playhead is being projected locally between pushes, and a `history incomplete` badge when a sequence gap proves updates were lost.
- **Convergence check** — the merge-strategy picker and the live property report.
- **Capabilities** — what the device *advertises* against what it has actually *demonstrated*. These diverge, and the divergence is the point.
- **Drive it** — `Deliver burst` pushes another mangled burst through; `Set volume 0.9` issues a command and paints it optimistically; `Expire pending` ages in-flight commands out unacknowledged.
- **Delivered** — a per-envelope log tagged `applied` / `superseded` / `replay` / `gap +n`.

### The sequence worth trying

Tap **Set volume 0.9**, then **Expire pending**. Three times.

The endpoint advertises `absoluteVolume` and never acknowledges anything. On the third expiry the trust ledger withdraws the capability — `effective` visibly loses `absoluteVolume` while `advertised` still lists it — and the next command reports `degraded from absoluteVolume`: it goes out as a relative nudge instead of pretending to work.

That's the contract this repo exists to demonstrate. **Degrade, don't lie.**

## How to run it

```bash
git clone https://github.com/rajatslakhina/remote-session-convergence-kit-demo-app.git
cd remote-session-convergence-kit-demo-app
open Demo.xcodeproj
```

Select the **Demo** scheme, pick any iOS Simulator, and press ⌘R. Xcode resolves `RemoteSessionConvergenceKit` from GitHub on first open — there is no local package path, so the resolution is the real thing.

Requires Xcode 16+ / iOS 17+.

## How it depends on the library

`Demo.xcodeproj` references the package as an `XCRemoteSwiftPackageReference` at its real GitHub URL, pinned to a **version**, not a branch:

```
repositoryURL = "https://github.com/rajatslakhina/remote-session-convergence-kit.git";
requirement = { kind = upToNextMajorVersion; minimumVersion = 1.0.0; };
```

Branch-tracking would mean every clone and every CI run resolves whatever `main` happened to be that day, which is the wrong default for something meant to still build in a year.

The app owns `DemoConfiguration` — the scenario, transport profile and staleness policy the console takes as a parameter. The package deliberately ships no sample session, so an integrator adopting it doesn't have to strip out someone else's fixture data.

## Verification

Both repositories are published, and the library is tagged [`v1.0.0`](https://github.com/rajatslakhina/remote-session-convergence-kit/releases/tag/v1.0.0) — which is the version `Demo.xcodeproj` pins, so package resolution has a real tag to resolve against.

### It was built and run on a Simulator

Built and launched on **iPhone 17 Pro, iOS 26.3, Xcode 26.3**, and driven far enough to read the screen.

On first launch, before any tap, the console rendered:

```
REMOTE SESSION
Ashes of Orion
Kepler Field
[fresh] [extrapolated] [history incomplete]
3:00                                    3:34

CONVERGENCE CHECK
[ Stamped LWW ][ Naive overwrite ]
PASS   PASS — 13 envelopes, 96 orderings agree

CAPABILITIES
device        living-room-speaker
advertised    transport, seek, absoluteVolume, relativeVolume, skip
effective     transport, seek, absoluteVolume, relativeVolume, skip
volume        0.40
in flight     0
```

That `PASS — 13 envelopes, 96 orderings agree` is the string this README quotes at the top and that `testHostileDemoStreamNumbersAreStable` pins in the library's suite. It was **read off the device**, not copied from the test.

**There are no screenshot files in this repository.** Two real captures were taken, but the automated session that produced this repo could only commit text through GitHub's web editor and had no path for binary uploads. Rather than embed a broken image link, the transcript above is what that run actually showed. Clone it and press ⌘R if you want the pixels — it takes about a minute.

### The Simulator run found four real bugs

This is the part worth reading, because it is the argument for why "it builds" is not a substitute for "it ran."

Everything in this project passed a clean Linux build with `-warnings-as-errors` and a 94-test suite **before** any of this was compiled for Apple platforms. The Linux job skips `ConvergenceConsole.swift` entirely via `#if canImport(SwiftUI)`, so the SwiftUI layer had only ever been *parsed*. The first real build surfaced three compile errors and one runtime fault, none of which any amount of Linux CI would ever have caught:

| # | Symptom | Cause |
|---|---|---|
| 1 | `initializer 'init(_:)' requires that 'Binding<Subject>' conform to 'StringProtocol'` | A bare `ForEach(MergeStrategy.allCases) { Text($0.rawValue) }` resolved to `ForEach`'s **binding** overload, so `$0` was `Binding<MergeStrategy>` and `$0.rawValue` became `Binding<String>` via dynamic member lookup. Fixed with an explicit `id:` and a named parameter. |
| 2 | `missing argument label '_immutableCocoaArray:' in call` | `Array(model.log.suffix(14))` inside a `ViewBuilder`. The real problem is an `ArraySlice`; the diagnostic is what Swift emits once overload resolution has already failed. Fixed by hoisting it to a computed property with an explicit `[DeliveryRecord]` return type. |
| 3 | `static property 'orange' requires the types 'HierarchicalShapeStyle' and 'Color'…` | `foregroundStyle(cond ? .secondary : .orange)` — `.secondary` is a `HierarchicalShapeStyle`, `.orange` is a `Color`, and the ternary has no common type. Fixed by spelling both `Color`. |
| 4 | `NSCocoaErrorDomain Code=2048 "Format '%.2f' does not match expected '%lld'"` — logged at **runtime**, visible in Xcode's console | `String(format:)` erases arguments to `CVarArg`, so a format/type mismatch is invisible to the compiler. Fixed by removing `String(format:)` from this file entirely and building both strings arithmetically. |

The fourth one is the one that argues hardest for actually running the thing: it compiled cleanly, rendered the correct value on screen, and still logged an error on every frame.

### Status of each claim

| Claim | Status |
|---|---|
| Compiles and launches on iOS Simulator | **Yes** — verified above. |
| Resolves the library as a **remote** GitHub package | **Yes — by CI, not by the Simulator run.** The library was unpublished when the app was run locally, so that run used a local package path. This repo's `Resolve package dependencies` step is what actually pulls the package from GitHub at `1.0.0`, and it passes. |
| Interactive behaviour driven by hand on the device | **No.** Clicks into the Simulator window were blocked by the host environment, so only the default state was exercised by hand. The interactions this README describes — the strategy toggle and the three-round degrade sequence — are covered by passing tests in `ConvergenceConsoleModelTests`, not by manual tapping. |
| CI | **Green.** See the [Actions tab](https://github.com/rajatslakhina/remote-session-convergence-kit-demo-app/actions) — `xcodebuild -resolvePackageDependencies` then a build for `generic/platform=iOS Simulator`, no named device, so the job does not depend on which simulator runtimes that day's runner image happens to carry. |

### What else was verified

| Check | Result |
|---|---|
| `Demo.xcodeproj/project.pbxproj` parsed by an old-style-plist parser | parses cleanly; **23 objects**; braces and parens balanced; every referenced object id defined; no duplicates; `rootObject` resolves |
| Package reference | `XCRemoteSwiftPackageReference` → `https://github.com/rajatslakhina/remote-session-convergence-kit.git`, `upToNextMajorVersion` from `1.0.0` — no local path, no branch pin |
| Product dependency wiring | `XCSwiftPackageProductDependency` for `RemoteSessionConvergenceKit`, referenced from both the target's `packageProductDependencies` and its Frameworks build phase |
| `swiftc -swift-version 6 -parse` on `DemoApp.swift`, `DemoConfiguration.swift` | both parse |

That is structural validation of the *committed* project file — the one with the remote pin. The Simulator run compiled the same project with a local package path; CI is what compiles it with the remote one.

### What the library verified

The behaviour this app puts on screen is covered by the library's own suite: **94 tests, 0 failures** on Swift 6.0.3, from a clean build with `-warnings-as-errors`. That includes `ConvergenceConsoleModelTests`, which asserts the three things this README promises a reader will see — the default screen is populated on launch, the strategy toggle flips `PASS` to `FAIL`, and the documented three-round volume sequence actually reaches a degrade.

The split that made this possible is worth stating: `ConvergenceConsoleModel` imports `Observation` rather than `SwiftUI`, so Linux CI compiles and tests it. Only `ConvergenceConsoleView` — pure layout — is Apple-only, and the Simulator run above is what covers it.

## Related

- **[remote-session-convergence-kit](https://github.com/rajatslakhina/remote-session-convergence-kit)** — the library this app consumes.

## Licence

MIT — see [LICENSE](LICENSE).
# RemoteSessionConvergenceKit — Demo App

**A merge strategy you can watch fail.**

This is a runnable iOS app around [`RemoteSessionConvergenceKit`](https://github.com/rajatslakhina/remote-session-convergence-kit). It simulates the transport a remote Now Playing session actually runs on — a push channel that **drops**, **reorders** and **coalesces** — feeds the survivors into the convergence engine, and then, on the same screen, runs the convergence properties live and shows you whether they hold.

The important control is one segmented picker:

| Strategy | What happens on screen |
|---|---|
| **Stamped LWW** | `PASS — 13 envelopes, 96 orderings agree` |
| **Naive overwrite** | `FAIL — 2 violation(s): commutativity, monotonicity`, with the counterexample printed |

Same envelopes. Same lossy transport. One merge rule apart.

Those two strings are exact. The default burst generates 46 envelopes and the hostile transport lands 13 of them — a 72% loss rate, which is what "best-effort, coalescing" actually means. Both figures are pinned by `testHostileDemoStreamNumbersAreStable` in the library's suite, so a stale README here is a failing test rather than something you have to notice.

## Why this matters

The naive strategy isn't a straw man — it's what a first-draft push handler does, and it's *correct* on an ordered transport. It stays correct right up until the first reordered delivery, and then it fails the way distributed bugs fail: no crash, no error, just two phones showing two different screens for one speaker and nobody able to reproduce it.

Being able to flip between the two, on real deliveries, in one tap, is the whole point of shipping this as an app rather than a paragraph.

## What's on screen

- **Now playing** — the converged session, with a freshness badge (`fresh` → `aging` → `stale` → `presumedLost`), an `extrapolated` badge when the playhead is being projected locally between pushes, and a `history incomplete` badge when a sequence gap proves updates were lost.
- **Convergence check** — the merge-strategy picker and the live property report.
- **Capabilities** — what the device *advertises* against what it has actually *demonstrated*. These diverge, and the divergence is the point.
- **Drive it** — `Deliver burst` pushes another mangled burst through; `Set volume 0.9` issues a command and paints it optimistically; `Expire pending` ages in-flight commands out unacknowledged.
- **Delivered** — a per-envelope log tagged `applied` / `superseded` / `replay` / `gap +n`.

### The sequence worth trying

Tap **Set volume 0.9**, then **Expire pending**. Three times.

The endpoint advertises `absoluteVolume` and never acknowledges anything. On the third expiry the trust ledger withdraws the capability — `effective` visibly loses `absoluteVolume` while `advertised` still lists it — and the next command reports `degraded from absoluteVolume`: it goes out as a relative nudge instead of pretending to work.

That's the contract this repo exists to demonstrate. **Degrade, don't lie.**

## How to run it

```bash
git clone https://github.com/rajatslakhina/remote-session-convergence-kit-demo-app.git
cd remote-session-convergence-kit-demo-app
open Demo.xcodeproj
```

Select the **Demo** scheme, pick any iOS Simulator, and press ⌘R. Xcode resolves `RemoteSessionConvergenceKit` from GitHub on first open — there is no local package path, so the resolution is the real thing.

Requires Xcode 16+ / iOS 17+.

## How it depends on the library

`Demo.xcodeproj` references the package as an `XCRemoteSwiftPackageReference` at its real GitHub URL, pinned to a **version**, not a branch:

```
repositoryURL = "https://github.com/rajatslakhina/remote-session-convergence-kit.git";
requirement = { kind = upToNextMajorVersion; minimumVersion = 1.0.0; };
```

Branch-tracking would mean every clone and every CI run resolves whatever `main` happened to be that day, which is the wrong default for something meant to still build in a year.

The app owns `DemoConfiguration` — the scenario, transport profile and staleness policy the console takes as a parameter. The package deliberately ships no sample session, so an integrator adopting it doesn't have to strip out someone else's fixture data.

## Verification

Both repositories are published, and the library is tagged [`v1.0.0`](https://github.com/rajatslakhina/remote-session-convergence-kit/releases/tag/v1.0.0) — which is the version `Demo.xcodeproj` pins, so package resolution has a real tag to resolve against.

### It was built and run on a Simulator

Built and launched on **iPhone 17 Pro, iOS 26.3, Xcode 26.3**, and driven far enough to read the screen.

On first launch, before any tap, the console rendered:

```
REMOTE SESSION
Ashes of Orion
Kepler Field
[fresh] [extrapolated] [history incomplete]
3:00                                    3:34

CONVERGENCE CHECK
[ Stamped LWW ][ Naive overwrite ]
PASS   PASS — 13 envelopes, 96 orderings agree

CAPABILITIES
device        living-room-speaker
advertised    transport, seek, absoluteVolume, relativeVolume, skip
effective     transport, seek, absoluteVolume, relativeVolume, skip
volume        0.40
in flight     0
```

That `PASS — 13 envelopes, 96 orderings agree` is the string this README quotes at the top and that `testHostileDemoStreamNumbersAreStable` pins in the library's suite. It was **read off the device**, not copied from the test.

**There are no screenshot files in this repository.** Two real captures were taken, but the automated session that produced this repo could only commit text through GitHub's web editor and had no path for binary uploads. Rather than embed a broken image link, the transcript above is what that run actually showed. Clone it and press ⌘R if you want the pixels — it takes about a minute.

### The Simulator run found four real bugs

This is the part worth reading, because it is the argument for why "it builds" is not a substitute for "it ran."

Everything in this project passed a clean Linux build with `-warnings-as-errors` and a 94-test suite **before** any of this was compiled for Apple platforms. The Linux job skips `ConvergenceConsole.swift` entirely via `#if canImport(SwiftUI)`, so the SwiftUI layer had only ever been *parsed*. The first real build surfaced three compile errors and one runtime fault, none of which any amount of Linux CI would ever have caught:

| # | Symptom | Cause |
|---|---|---|
| 1 | `initializer 'init(_:)' requires that 'Binding<Subject>' conform to 'StringProtocol'` | A bare `ForEach(MergeStrategy.allCases) { Text($0.rawValue) }` resolved to `ForEach`'s **binding** overload, so `$0` was `Binding<MergeStrategy>` and `$0.rawValue` became `Binding<String>` via dynamic member lookup. Fixed with an explicit `id:` and a named parameter. |
| 2 | `missing argument label '_immutableCocoaArray:' in call` | `Array(model.log.suffix(14))` inside a `ViewBuilder`. The real problem is an `ArraySlice`; the diagnostic is what Swift emits once overload resolution has already failed. Fixed by hoisting it to a computed property with an explicit `[DeliveryRecord]` return type. |
| 3 | `static property 'orange' requires the types 'HierarchicalShapeStyle' and 'Color'…` | `foregroundStyle(cond ? .secondary : .orange)` — `.secondary` is a `HierarchicalShapeStyle`, `.orange` is a `Color`, and the ternary has no common type. Fixed by spelling both `Color`. |
| 4 | `NSCocoaErrorDomain Code=2048 "Format '%.2f' does not match expected '%lld'"` — logged at **runtime**, visible in Xcode's console | `String(format:)` erases arguments to `CVarArg`, so a format/type mismatch is invisible to the compiler. Fixed by removing `String(format:)` from this file entirely and building both strings arithmetically. |

The fourth one is the one that argues hardest for actually running the thing: it compiled cleanly, rendered the correct value on screen, and still logged an error on every frame.

### What is still not verified

| Claim | Status |
|---|---|
| Compiles and launches on iOS Simulator | **Yes** — verified above. |
| Resolves the library as a **remote** GitHub package | **Not yet.** The library was unpublished at the time of the Simulator run, so that run used a local-path copy of the same sources purely to get a compiler on them. The project committed here uses the version-pinned remote reference, and the CI job on this repo is the first thing to exercise it. |
| Interactive behaviour driven by hand on the device | **No.** Clicks into the Simulator window were blocked by the host environment, so only the default state was exercised by hand. The interactions this README describes — the strategy toggle and the three-round degrade sequence — are covered by passing tests in `ConvergenceConsoleModelTests`, not by manual tapping. |
| CI | See the [Actions tab](https://github.com/rajatslakhina/remote-session-convergence-kit-demo-app/actions). It resolves the remote package at `1.0.0` and compiles for `generic/platform=iOS Simulator`. |

### What else was verified

| Check | Result |
|---|---|
| `Demo.xcodeproj/project.pbxproj` parsed by an old-style-plist parser | parses cleanly; **23 objects**; braces and parens balanced; every referenced object id defined; no duplicates; `rootObject` resolves |
| Package reference | `XCRemoteSwiftPackageReference` → `https://github.com/rajatslakhina/remote-session-convergence-kit.git`, `upToNextMajorVersion` from `1.0.0` — no local path, no branch pin |
| Product dependency wiring | `XCSwiftPackageProductDependency` for `RemoteSessionConvergenceKit`, referenced from both the target's `packageProductDependencies` and its Frameworks build phase |
| `swiftc -swift-version 6 -parse` on `DemoApp.swift`, `DemoConfiguration.swift` | both parse |

That is structural validation of the *committed* project file — the one with the remote pin. The Simulator run compiled the same project with a local package path; CI is what compiles it with the remote one.

### What the library verified

The behaviour this app puts on screen is covered by the library's own suite: **94 tests, 0 failures** on Swift 6.0.3, from a clean build with `-warnings-as-errors`. That includes `ConvergenceConsoleModelTests`, which asserts the three things this README promises a reader will see — the default screen is populated on launch, the strategy toggle flips `PASS` to `FAIL`, and the documented three-round volume sequence actually reaches a degrade.

The split that made this possible is worth stating: `ConvergenceConsoleModel` imports `Observation` rather than `SwiftUI`, so Linux CI compiles and tests it. Only `ConvergenceConsoleView` — pure layout — is Apple-only, and the Simulator run above is what covers it.

## Related

- **[remote-session-convergence-kit](https://github.com/rajatslakhina/remote-session-convergence-kit)** — the library this app consumes.

## Licence

MIT — see [LICENSE](LICENSE).
