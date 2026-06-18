# sort-search: generate N integers, sort them with a hand-written median-of-three
# quicksort (Hoare partition), then run N binary searches and fold the found indices
# into a checksum. The two classic algorithms - quicksort and binary search - written
# out explicitly (no stdlib sort/bsearch), so this measures the LANGUAGE executing the
# SAME algorithm, consistent with the suite's no-stdlib-shortcut rule. All integer.

P = 1000000007

def lcg_next(s)
  (s * 1103515245 + 12345) & 0x7fffffff
end

# median-of-three + Hoare partition, recurse both sides; depth stays ~log N.
def qsort_h(a, lo, hi)
  return if lo >= hi
  mid = lo + (hi - lo) / 2
  a[lo], a[mid] = a[mid], a[lo] if a[mid] < a[lo]
  a[lo], a[hi]  = a[hi], a[lo]  if a[hi]  < a[lo]
  a[mid], a[hi] = a[hi], a[mid] if a[hi]  < a[mid]
  pivot = a[mid]
  i = lo - 1
  j = hi + 1
  loop do
    i += 1
    i += 1 while a[i] < pivot
    j -= 1
    j -= 1 while a[j] > pivot
    break if i >= j
    a[i], a[j] = a[j], a[i]
  end
  qsort_h(a, lo, j)
  qsort_h(a, j + 1, hi)
end

def bsearch_i(a, n, key)
  lo = 0
  hi = n - 1
  while lo <= hi
    mid = lo + (hi - lo) / 2
    if a[mid] < key
      lo = mid + 1
    elsif a[mid] > key
      hi = mid - 1
    else
      return mid
    end
  end
  -1
end

def sort_search(n)
  a = Array.new(n, 0)
  state = 42
  i = 0
  while i < n
    state = lcg_next(state)
    a[i] = state
    i += 1
  end
  qsort_h(a, 0, n - 1)
  h = 0
  q = 0
  while q < n
    state = lcg_next(state)
    key = a[state % n] # a value present in the sorted array -> a hit
    idx = bsearch_i(a, n, key)
    h = (h * 31 + (idx + 1)) % P
    q += 1
  end
  h
end

n = ARGV[0] ? ARGV[0].to_i : 200000
puts sort_search(n)
puts "sort-search(#{n})"
