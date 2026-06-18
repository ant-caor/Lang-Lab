P = 1000000007
INF = 1 << 62
DEG = 8            # average out-degree -> M = DEG*N directed edges
MAXW = 100         # edge weights 1..MAXW
BASE = 2097152     # 2^21, larger than N; node packs into the low bits

def dijkstra(n)
  m = DEG * n
  # generate the weighted digraph with the pinned LCG, forward adjacency order
  adj = Array.new(n) { [] }
  s = 42
  m.times do
    s = (s * 1103515245 + 12345) & 0x7fffffff
    u = s % n
    s = (s * 1103515245 + 12345) & 0x7fffffff
    v = s % n
    s = (s * 1103515245 + 12345) & 0x7fffffff
    w = s % MAXW + 1
    adj[u] << [v, w]
  end

  dist = Array.new(n, INF)
  dist[0] = 0

  # hand-written binary min-heap of packed long keys (all keys distinct)
  heap = [0]                                   # pack(0, 0) = 0
  hsize = 1
  while hsize > 0
    # extract-min: top, then move last to root and sift down
    key = heap[0]
    hsize -= 1
    heap[0] = heap[hsize]
    i = 0
    loop do
      l = 2 * i + 1
      r = 2 * i + 2
      mn = i
      mn = l if l < hsize && heap[l] < heap[mn]
      mn = r if r < hsize && heap[r] < heap[mn]
      break if mn == i
      heap[mn], heap[i] = heap[i], heap[mn]
      i = mn
    end

    d = key / BASE
    u = key % BASE
    next if d > dist[u]                        # stale heap entry
    adj[u].each do |v, w|
      nd = d + w
      if nd < dist[v]
        dist[v] = nd
        # push: append packed key, then sift up
        k = nd * BASE + v
        if hsize < heap.length
          heap[hsize] = k
        else
          heap << k
        end
        i = hsize
        hsize += 1
        while i > 0
          par = (i - 1) / 2
          break if heap[par] <= heap[i]
          heap[par], heap[i] = heap[i], heap[par]
          i = par
        end
      end
    end
  end

  h = 0
  n.times do |i|
    di = dist[i] < INF ? dist[i] : 0           # unreachable -> 0
    h = (h * 31 + di % P) % P
  end
  h
end

n = ARGV[0] ? ARGV[0].to_i : 20000
puts dijkstra(n)
puts "dijkstra(#{n})"
