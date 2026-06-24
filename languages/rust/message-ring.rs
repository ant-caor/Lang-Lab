// message-ring: cooperative concurrency / message-passing overhead axis.
// 32 workers in a ring, driven for N laps. Measures per-handoff instruction cost
// of a cooperative context switch. Single OS thread throughout.
//
// Cooperative primitive: hand-rolled single-threaded executor polling 32 explicit
// Future state machines (std-only). One-slot rendezvous channels (Cell<Option<u32>>)
// serve as the handoff medium. Each Poll::Pending IS the cooperative yield / context
// switch being measured. No tokio, no async-std, no external crates.
//
// Written as manual Future impls (no async/await) so it compiles under the default
// Rust 2015 edition that the lang-lab Dockerfile uses (rustc -O without --edition).
//
// Algorithm: RING_WIDTH=32, SEED=12345, MOD=1_000_000_007
//   worker(id): v = recv; v = v.wrapping_mul(1103515245).wrapping_add(id as u32+1); send(v)
//   main: v=SEED; for lap in 0..N { send(v)->worker0; v = recv<-worker31 }
//   output line1 = v%MOD, line2 = N*RING_WIDTH

use std::cell::Cell;
use std::env;
use std::future::Future;
use std::pin::Pin;
use std::task::{Context, Poll, RawWaker, RawWakerVTable, Waker};

const RING_WIDTH: usize = 32;
const SEED: u32 = 12345;
const MOD: u64 = 1_000_000_007;

// ---------------------------------------------------------------------------
// One-slot rendezvous channel (single-threaded Cell, no sync needed)
// ---------------------------------------------------------------------------

struct Slot(Cell<Option<u32>>);

impl Slot {
    fn new() -> Self {
        Slot(Cell::new(None))
    }

    fn put(&self, v: u32) {
        self.0.set(Some(v));
    }

    fn take(&self) -> Option<u32> {
        let v = self.0.get();
        if v.is_some() {
            self.0.set(None);
        }
        v
    }
}

// SAFETY: This file is entirely single-threaded. The Slot never crosses thread
// boundaries; Sync is needed only because the executor holds &Slot references
// behind Pin<Box<dyn Future>> trait objects.
unsafe impl Sync for Slot {}

// ---------------------------------------------------------------------------
// Minimal no-op Waker (executor is a poll loop, not event-driven)
// ---------------------------------------------------------------------------

unsafe fn noop_clone(_: *const ()) -> RawWaker {
    RawWaker::new(std::ptr::null(), &NOOP_VTABLE)
}
unsafe fn noop_wake(_: *const ()) {}
unsafe fn noop_wake_by_ref(_: *const ()) {}
unsafe fn noop_drop(_: *const ()) {}

static NOOP_VTABLE: RawWakerVTable =
    RawWakerVTable::new(noop_clone, noop_wake, noop_wake_by_ref, noop_drop);

fn noop_waker() -> Waker {
    // SAFETY: vtable methods are all no-ops; data pointer is null.
    unsafe { Waker::from_raw(RawWaker::new(std::ptr::null(), &NOOP_VTABLE)) }
}

// ---------------------------------------------------------------------------
// Worker future: explicit state machine (avoids async/await, compiles in 2015)
// ---------------------------------------------------------------------------
//
// States per lap:
//   WaitRecv : poll inbox until it has a value (Poll::Pending while empty)
//   WaitSend : poll outbox until it is empty, then write (Poll::Pending while full)
//
// After `laps_left` drops to 0 the future returns Poll::Ready(()).

enum WorkerState {
    WaitRecv,
    WaitSend(u32),
    Done,
}

struct WorkerFut {
    id: u32,
    laps_left: usize,
    inbox: *const Slot,
    outbox: *const Slot,
    state: WorkerState,
}

// SAFETY: WorkerFut is used on a single thread; the raw pointers are stable
// (Slot lives in a Vec that is never moved after creation).
unsafe impl Send for WorkerFut {}

impl Future for WorkerFut {
    type Output = ();

    fn poll(mut self: Pin<&mut Self>, _cx: &mut Context<'_>) -> Poll<()> {
        loop {
            match self.state {
                WorkerState::Done => return Poll::Ready(()),

                WorkerState::WaitRecv => {
                    // SAFETY: inbox pointer is valid for the lifetime of the executor loop.
                    let inbox = unsafe { &*self.inbox };
                    match inbox.take() {
                        None => return Poll::Pending,
                        Some(v) => {
                            // Transform happens INSIDE the worker (fairness rule 2).
                            let v = v.wrapping_mul(1103515245).wrapping_add(self.id + 1);
                            self.state = WorkerState::WaitSend(v);
                            // Fall through to WaitSend in next loop iteration.
                        }
                    }
                }

                WorkerState::WaitSend(v) => {
                    // SAFETY: outbox pointer is valid for the lifetime of the executor loop.
                    let outbox = unsafe { &*self.outbox };
                    if outbox.0.get().is_some() {
                        // Outbox still occupied; yield.
                        return Poll::Pending;
                    }
                    outbox.put(v);
                    self.laps_left -= 1;
                    if self.laps_left == 0 {
                        self.state = WorkerState::Done;
                        return Poll::Ready(());
                    }
                    self.state = WorkerState::WaitRecv;
                    // Loop back to WaitRecv.
                }
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

fn main() {
    let n: usize = env::args()
        .nth(1)
        .and_then(|s| s.parse().ok())
        .unwrap_or(2000);

    // RING_WIDTH+1 slots: slot[i] feeds worker[i] (i in 0..RING_WIDTH-1),
    // slot[RING_WIDTH] is worker31 -> main.
    let slots: Vec<Slot> = (0..=RING_WIDTH).map(|_| Slot::new()).collect();

    // Create all 32 worker futures once (before the lap loop).
    // WorkerFut holds raw pointers into `slots`; slots must not move after this.
    let mut futures: Vec<Pin<Box<WorkerFut>>> = (0..RING_WIDTH)
        .map(|id| {
            Box::pin(WorkerFut {
                id: id as u32,
                laps_left: n,
                inbox: &slots[id] as *const Slot,
                outbox: &slots[id + 1] as *const Slot,
                state: WorkerState::WaitRecv,
            })
        })
        .collect();

    let waker = noop_waker();
    let mut cx = Context::from_waker(&waker);

    let main_out = &slots[0];            // main -> worker 0
    let main_in = &slots[RING_WIDTH];    // worker 31 -> main

    let mut v: u32 = SEED;

    for _lap in 0..n {
        // Deposit token for worker 0.
        main_out.put(v);

        // Round-robin poll loop: poll all workers until one lap completes
        // (detected when main_in has a value deposited by worker 31).
        loop {
            for fut in futures.iter_mut() {
                let _ = fut.as_mut().poll(&mut cx);
            }
            if let Some(result) = main_in.take() {
                v = result;
                break;
            }
        }
    }

    println!("{}", v as u64 % MOD);
    println!("{}", n * RING_WIDTH);
}
