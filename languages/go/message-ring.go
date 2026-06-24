// message-ring: cooperative concurrency / message-passing overhead axis.
// A ring of RING_WIDTH=32 goroutines connected by unbuffered channels. Main drives N laps,
// sending a token through every worker in order. Each worker applies a deterministic LCG
// transform (v = v*1103515245 + (id+1) mod 2^32) and forwards the token. No shared mutable
// state; all communication is via channel handoffs. Measures per-handoff instruction cost of
// goroutines + unbuffered channels (the cooperative rendezvous primitive in Go).
//
// Each worker is given N and loops exactly N times, then returns -- the same bounded-loop shape
// as every other language's worker in this benchmark. The hot loop contains ONLY the receive +
// transform + send, so the differential isolates the handoff cost. (An earlier version selected on
// a `done` channel every hop for shutdown; that put non-handoff work in the measured loop and
// inflated the per-hop cost ~1.76x. Workers now terminate naturally by finishing N laps.)
//
// Determinism: GOMAXPROCS=1 (pinned via runtimeEnv in languages.json) collapses all 32
// goroutines onto a single OS thread. asyncpreemptoff=1 prevents signal-based preemption
// from interrupting a channel-blocked goroutine mid-count. GOGC=off removes GC jitter.
package main

import (
	"fmt"
	"os"
	"strconv"
)

const (
	RING_WIDTH = 32
	SEED       = 12345
	MOD        = 1000000007
	LCG_MUL    = 1103515245
)

func worker(id uint32, in <-chan uint32, out chan<- uint32, n int) {
	addend := id + 1
	for lap := 0; lap < n; lap++ {
		v := <-in
		out <- v*LCG_MUL + addend
	}
}

func main() {
	n := 500
	if len(os.Args) > 1 {
		if v, err := strconv.Atoi(os.Args[1]); err == nil {
			n = v
		}
	}

	// Build the ring: one unbuffered channel per worker (channel[i] feeds worker i).
	// main -> ch[0] -> worker0 -> ch[1] -> worker1 -> ... -> worker31 -> out -> main
	ch := make([]chan uint32, RING_WIDTH)
	for i := range ch {
		ch[i] = make(chan uint32)
	}
	out := make(chan uint32)

	for i := 0; i < RING_WIDTH; i++ {
		var next chan<- uint32
		if i == RING_WIDTH-1 {
			next = out
		} else {
			next = ch[i+1]
		}
		go worker(uint32(i), ch[i], next, n)
	}

	var v uint32 = SEED
	for lap := 0; lap < n; lap++ {
		ch[0] <- v
		v = <-out
	}

	fmt.Println(uint64(v) % MOD)
	fmt.Println(n * RING_WIDTH)
}
