# gemm: quantized integer matrix-multiply - the dominant ML inference kernel.
# Square matmul of side N (i.e. N x N matrices). Loop order i,k,j (pinned)
# so B is accessed row-sequentially. LCG fills A then B with values 0..127.
# Accumulator is 64-bit; checksum = poly-hash of C row-major mod 1e9+7.
# No BLAS / no library matmul - the explicit triple loop.

P = 1000000007

def gemm(n)
  a = Array.new(n * n, 0)
  b = Array.new(n * n, 0)

  state = 42
  (n * n).times do |i|
    state = (state * 1103515245 + 12345) & 0x7fffffff
    a[i] = state % 128
  end
  (n * n).times do |i|
    state = (state * 1103515245 + 12345) & 0x7fffffff
    b[i] = state % 128
  end

  c = Array.new(n * n, 0)

  # Pinned loop order i, k, j - B read row-sequentially.
  i = 0
  while i < n
    k = 0
    while k < n
      av   = a[i * n + k]
      kn   = k * n
      base = i * n
      j = 0
      while j < n
        c[base + j] += av * b[kn + j]
        j += 1
      end
      k += 1
    end
    i += 1
  end

  h = 0
  (n * n).times { |i| h = (h * 31 + c[i] % P) % P }
  secondary = c[n * n - 1] % P
  [h, secondary]
end

n = ARGV[0] ? ARGV[0].to_i : 256
h, sec = gemm(n)
puts h
puts "gemm(#{n}) = #{sec}"
