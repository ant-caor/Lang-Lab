# viterbi: integer HMM sequence decoding — the classical max-plus trellis.
# S=8 states, ALPHA=4 symbols, T=size parameter. LCG (glibc-style, seed=42)
# draws trans[S*S], emit[S*ALPHA], obs[T] in that order. Forward pass is a
# loop-carried max-reduction (STRICT > tie-break: lowest i wins), followed by
# a pointer-chain backtrace. Checksum = poly-hash of (path[t]+1).
# Secondary = optimal total path score mod P. No HMM library; pure integer.

S     = 8
ALPHA = 4
P     = 1000000007

def viterbi(t)
  # Draw order: trans[S*S], emit[S*ALPHA], obs[T]
  trans = Array.new(S * S, 0)
  emit  = Array.new(S * ALPHA, 0)
  obs   = Array.new(t, 0)
  state = 42
  (S * S).times do |x|
    state = (state * 1103515245 + 12345) & 0x7fffffff
    trans[x] = state % 100 + 1
  end
  (S * ALPHA).times do |x|
    state = (state * 1103515245 + 12345) & 0x7fffffff
    emit[x] = state % 100 + 1
  end
  t.times do |i|
    state = (state * 1103515245 + 12345) & 0x7fffffff
    obs[i] = state % ALPHA
  end

  # Initialise t=0
  vit_prev = Array.new(S) { |j| emit[j * ALPHA + obs[0]] }
  vit_next = Array.new(S, 0)

  back = Array.new(t * S, 0)

  # Forward trellis ti=1..T-1
  ti = 1
  while ti < t
    j = 0
    while j < S
      best = -1; bi = 0
      e = emit[j * ALPHA + obs[ti]]
      i = 0
      while i < S
        sc = vit_prev[i] + trans[i * S + j] + e
        if sc > best    # STRICT > -> lowest i wins
          best = sc; bi = i
        end
        i += 1
      end
      vit_next[j] = best
      back[ti * S + j] = bi
      j += 1
    end
    vit_prev, vit_next = vit_next, vit_prev
    ti += 1
  end

  # Final state: STRICT > -> lowest j wins
  bf = 0
  j = 1
  while j < S
    bf = j if vit_prev[j] > vit_prev[bf]
    j += 1
  end

  # Backtrace
  path = Array.new(t, 0)
  path[t - 1] = bf
  ti = t - 2
  while ti >= 0
    path[ti] = back[(ti + 1) * S + path[ti + 1]]
    ti -= 1
  end

  # Checksum
  h = 0
  t.times { |i| h = (h * 31 + path[i] + 1) % P }

  secondary = vit_prev[bf] % P
  [h, secondary]
end

t = ARGV[0] ? ARGV[0].to_i : 20000
h, sec = viterbi(t)
puts h
puts "viterbi(#{t}) = #{sec}"
