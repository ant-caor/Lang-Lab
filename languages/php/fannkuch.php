<?php

function fannkuch(int $n): array {
    $perm1 = range(0, $n - 1);
    $count = array_fill(0, $n, 0);
    $max_flips = 0;
    $checksum  = 0;
    $perm_idx  = 0;
    $r = $n;

    while (true) {
        while ($r != 1) {
            $count[$r - 1] = $r;
            $r--;
        }

        $perm = $perm1;
        $flips = 0;
        $k = $perm[0];
        while ($k != 0) {
            $i = 0;
            $j = $k;
            while ($i < $j) {
                $tmp = $perm[$i];
                $perm[$i] = $perm[$j];
                $perm[$j] = $tmp;
                $i++;
                $j--;
            }
            $flips++;
            $k = $perm[0];
        }

        if ($flips > $max_flips) {
            $max_flips = $flips;
        }
        $checksum += ($perm_idx % 2 == 0) ? $flips : -$flips;

        // Generate the next permutation.
        while (true) {
            if ($r == $n) {
                return [$max_flips, $checksum];
            }
            $first = $perm1[0];
            for ($i = 0; $i < $r; $i++) {
                $perm1[$i] = $perm1[$i + 1];
            }
            $perm1[$r] = $first;
            $count[$r]--;
            if ($count[$r] > 0) {
                break;
            }
            $r++;
        }
        $perm_idx++;
    }
}

$n = isset($argv[1]) ? (int)$argv[1] : 7;
[$max_flips, $checksum] = fannkuch($n);
echo "$checksum\n";
echo "Pfannkuchen($n) = $max_flips\n";
