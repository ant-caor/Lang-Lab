<?php

// polymorphism: dynamic-dispatch / virtual-call-overhead axis. N objects of K=6 concrete types in
// an unpredictable (megamorphic) order; fold acc through all of them M times via $obj->apply($acc).
// Each type has its own apply() formula; which one runs is resolved at RUNTIME from the object's
// class, never from a type tag + switch. PHP uses idiomatic duck-typed method dispatch through a
// shared interface. Checksum = the final accumulator. All integer (PHP ints are 64-bit signed; the
// widest intermediate is acc*1000003 < 1e9 * 1e6 = 1e15, well inside the 9.2e18 signed range).

const P = 1000000007;
const N = 10000;
const K = 6;

interface Apply {
    public function apply(int $x): int;
}

// Distinct large multipliers so the per-pass composition never reaches a fixed point: acc stays
// chaotic and the checksum depends on M (proof all N*M dispatches ran). Every type carries the
// SAME a,b,c fields but its OWN apply() body - the "virtual method".
class T0 implements Apply {
    public function __construct(public int $a, public int $b, public int $c) {}
    public function apply(int $x): int { return ($x * 1000003 + $this->a) % P; }
}

class T1 extends T0 {
    public function apply(int $x): int { return ($x * 998273 + $this->b) % P; }
}

class T2 extends T0 {
    public function apply(int $x): int { return ($x * 999983 + $this->c) % P; }
}

class T3 extends T0 {
    public function apply(int $x): int { return ($x * 997879 + $this->a + $this->b) % P; }
}

class T4 extends T0 {
    public function apply(int $x): int { return ($x * 996323 + $this->b * $this->c) % P; }
}

class T5 extends T0 {
    public function apply(int $x): int { return ($x * 995369 + $this->a + $this->c) % P; }
}

function lcg(int $s): int {
    return ($s * 1103515245 + 12345) & 0x7fffffff;
}

$M = isset($argv[1]) ? (int)$argv[1] : 50;

$types = ['T0', 'T1', 'T2', 'T3', 'T4', 'T5'];
$objs = [];
$s = 42;
for ($i = 0; $i < N; $i++) {
    $s = lcg($s); $t = ($s >> 16) % K;   // type from HIGH bits (LCG low bits correlate); all K used
    $s = lcg($s); $a = $s % 1000;
    $s = lcg($s); $b = $s % 1000;
    $s = lcg($s); $c = $s % 1000;
    $objs[] = new $types[$t]($a, $b, $c);
}

$acc = 1;
for ($pass = 0; $pass < $M; $pass++) {
    foreach ($objs as $o) {
        $acc = $o->apply($acc);   // DYNAMIC dispatch (runtime method resolution per object)
    }
}

echo $acc, "\n";
echo "polymorphism($M)\n";
