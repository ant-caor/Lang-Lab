<?php

// tak: Takeuchi function - the function-call / recursion-overhead axis. Naive triple recursion,
// no memoization, no iterative rewrite. Checksum = total number of calls (identical-recursion
// invariant); secondary = the returned value. Size n -> tak(3n, 2n, n). Pure integer, no memory.

$calls = 0;

function tak(int $x, int $y, int $z): int {
    global $calls;
    $calls++;
    if ($y < $x) {
        return tak(tak($x - 1, $y, $z), tak($y - 1, $z, $x), tak($z - 1, $x, $y));
    }
    return $z;
}

$n = isset($argv[1]) ? (int)$argv[1] : 6;
$r = tak(3 * $n, 2 * $n, $n);
echo "$calls\n";
echo "tak($n) = $r\n";
