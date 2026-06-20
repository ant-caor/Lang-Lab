// polymorphism: the dynamic-dispatch / virtual-call-overhead axis of the suite. Build N objects
// of K=6 distinct concrete types in an unpredictable LCG order (the call site stays MEGAMORPHIC,
// so no devirtualization / inline-cache win), then fold an accumulator through all of them M
// times: acc = obj.apply(acc). Each type has the SAME fields but its OWN apply() formula; which
// one runs is resolved at RUNTIME from the object's dynamic type. The acc threads through every
// call (a strict data dependency), so exactly N*M real dispatches happen and nothing can be
// hoisted - the only thing measured is the cost of that runtime dispatch.
//
// Go's idiomatic runtime polymorphism is INTERFACE dispatch: an interface Apply with six distinct
// struct types each implementing it, held in a []Apply. objs[i].apply(acc) is an itab/method
// call resolved from the value's dynamic type - NOT a source-level type switch (forbidden here).
package main

import (
	"fmt"
	"os"
	"strconv"
)

const (
	P = 1000000007
	N = 10000
	K = 6
)

// Apply is the "virtual method" - the megamorphic call site. Six concrete types implement it.
type Apply interface {
	apply(x int64) int64
}

// All six types share the SAME three fields; only their apply() formula differs. Embedding a
// common fields struct keeps the data layout identical while giving each type its own method set
// (so the call is genuine interface dispatch, not a tag branch).
type fields struct {
	a, b, c int64
}

type (
	T0 struct{ fields }
	T1 struct{ fields }
	T2 struct{ fields }
	T3 struct{ fields }
	T4 struct{ fields }
	T5 struct{ fields }
)

// Six distinct per-type transforms (the "virtual method" bodies). All integer, all use x so the
// dependency chain is real; distinct large multipliers keep acc chaotic (no fixed point) so the
// checksum depends on M. Pointer receivers: the []Apply holds *Tn, mirroring C's per-object
// vtable pointer.
func (o *T0) apply(x int64) int64 { return (x*1000003 + o.a) % P }
func (o *T1) apply(x int64) int64 { return (x*998273 + o.b) % P }
func (o *T2) apply(x int64) int64 { return (x*999983 + o.c) % P }
func (o *T3) apply(x int64) int64 { return (x*997879 + o.a + o.b) % P }
func (o *T4) apply(x int64) int64 { return (x*996323 + o.b*o.c) % P }
func (o *T5) apply(x int64) int64 { return (x*995369 + o.a + o.c) % P }

func lcg(s int64) int64 { return (s*1103515245 + 12345) & 0x7fffffff }

func polymorphism(m int) int64 {
	objs := make([]Apply, N)
	s := int64(42)
	for i := 0; i < N; i++ {
		s = lcg(s)
		t := (s >> 16) % K // type from HIGH bits (LCG low bits correlate); all K used -> megamorphic
		s = lcg(s)
		a := s % 1000
		s = lcg(s)
		b := s % 1000
		s = lcg(s)
		c := s % 1000
		f := fields{a, b, c}
		switch t {
		case 0:
			objs[i] = &T0{f}
		case 1:
			objs[i] = &T1{f}
		case 2:
			objs[i] = &T2{f}
		case 3:
			objs[i] = &T3{f}
		case 4:
			objs[i] = &T4{f}
		case 5:
			objs[i] = &T5{f}
		}
	}

	acc := int64(1)
	for pass := 0; pass < m; pass++ {
		for i := 0; i < N; i++ {
			acc = objs[i].apply(acc) // DYNAMIC dispatch (interface method call per object)
		}
	}
	return acc
}

func main() {
	m := 50
	if len(os.Args) > 1 {
		if v, err := strconv.Atoi(os.Args[1]); err == nil {
			m = v
		}
	}
	fmt.Println(polymorphism(m))
	fmt.Printf("polymorphism(%d)\n", m)
}
