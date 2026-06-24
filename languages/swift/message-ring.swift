// message-ring: cooperative concurrency / message-passing overhead axis.
// RING_WIDTH=32 workers in a ring, N laps. Each worker receives a UInt32 token, applies
// a glibc-style LCG transform (32-bit unsigned wrap), and forwards to the next worker.
// All tasks run on @MainActor (Swift's main-thread serial executor), so the ring stays
// on ONE OS thread, switching cooperatively via CheckedContinuation (async/await).
//
// Primitive: CheckedContinuation<UInt32, Never> on @MainActor.
// "Receive" = withCheckedContinuation (task suspends, stores continuation).
// "Send"    = call deliver() which resumes the stored continuation, waking the next worker.
// No thread pool, no DispatchQueue workers: pure cooperative @MainActor scheduling.

import Foundation

let RING_WIDTH = 32
let SEED: UInt32  = 12345
let MOD:  UInt32  = 1_000_000_007
let MUL:  UInt32  = 1_103_515_245

// RingNode: one cooperative worker slot. Holds its pending continuation and a closure
// pointing to the next entity in the ring. Using a closure avoids protocol overhead and
// lets worker[31] point directly to main's continuation slot without a separate type.
@MainActor
final class RingNode {
    let id: Int
    // Called to deliver an outgoing token to the NEXT entity in the ring.
    let forwardToken: (UInt32) -> Void
    // The continuation this node is waiting on (nil = not currently suspended).
    var waitingCont: CheckedContinuation<UInt32, Never>?

    init(id: Int, forwardToken: @escaping (UInt32) -> Void) {
        self.id  = id
        self.forwardToken = forwardToken
    }

    // Invoked by the *previous* ring entity to wake this node with token `v`.
    func deliver(_ v: UInt32) {
        waitingCont!.resume(returning: v)
        waitingCont = nil
    }

    // Worker loop: laps iterations of receive -> transform -> forward.
    // The transform lives inside the worker (fairness rule: not folded into main).
    func run(laps: Int) async {
        for _ in 0..<laps {
            let v: UInt32 = await withCheckedContinuation { c in
                waitingCont = c   // store so the previous entity can resume us
            }
            let out = v &* MUL &+ UInt32(id + 1)   // 32-bit unsigned wrap
            forwardToken(out)
        }
    }
}

@MainActor
func runBenchmark(n: Int) async -> UInt32 {
    // Slot for main's own continuation (receives the token from worker 31).
    var mainCont: CheckedContinuation<UInt32, Never>?

    // Build nodes right-to-left so each node's forward closure can capture the next node
    // (already allocated). Node 31 forwards back to main via mainCont.
    let node31 = RingNode(id: 31) { v in
        mainCont!.resume(returning: v)
        mainCont = nil
    }

    // Nodes 30..0: each forwards to the previously-built node (which has higher id).
    var nodes: [RingNode] = [node31]
    for i in stride(from: 30, through: 0, by: -1) {
        let next = nodes.last!   // next in ring = higher id
        nodes.append(RingNode(id: i) { [weak next] v in
            next!.deliver(v)
        })
    }
    // nodes is now [31, 30, ..., 0]; reverse to index by id.
    nodes.reverse()   // nodes[i].id == i

    // Spawn all 32 worker tasks on @MainActor. They will not run until we yield
    // (cooperative scheduler), at which point each task runs until it suspends
    // in withCheckedContinuation, storing its continuation.
    for node in nodes {
        let laps = n
        Task { @MainActor in
            await node.run(laps: laps)
        }
    }

    // Yield until every worker has parked in withCheckedContinuation and stored its cont.
    // On @MainActor this is safe: we're the only thing that can mutate waitingCont.
    while nodes.contains(where: { $0.waitingCont == nil }) {
        await Task.yield()
    }

    // Main lap loop: n laps.
    var v: UInt32 = SEED
    for _ in 0..<n {
        nodes[0].deliver(v)
        v = await withCheckedContinuation { c in
            mainCont = c
        }
    }

    return v
}

// Top-level entry: run on @MainActor via Task, drive the RunLoop with dispatchMain().
let n = CommandLine.arguments.count > 1 ? (Int(CommandLine.arguments[1]) ?? 2000) : 2000

Task { @MainActor in
    let v = await runBenchmark(n: n)
    print(v % MOD)
    print(n * RING_WIDTH)
    exit(0)
}
dispatchMain()
