# blur: a 2D image-convolution benchmark - the stencil axis of the suite. Generate a
# grayscale N x N image, then apply a 3x3 Gaussian blur kernel [1 2 1; 2 4 2; 1 2 1]/16
# PASSES times (double-buffered), with clamp (edge-replication) border handling, and reduce
# the result to a polynomial hash. All integer arithmetic - deterministic, no floating point.

P = 1000000007
PASSES = 4
K = [1, 2, 1, 2, 4, 2, 1, 2, 1].freeze  # 3x3, sum 16

def clampi(x, n)
  x < 0 ? 0 : (x >= n ? n - 1 : x)
end

def blur(n)
  src = Array.new(n * n, 0)
  dst = Array.new(n * n, 0)

  s = 42
  (n * n).times do |k|
    s = (s * 1103515245 + 12345) & 0x7FFFFFFF
    src[k] = s % 256
  end

  PASSES.times do
    n.times do |i|
      n.times do |j|
        acc = 0
        [-1, 0, 1].each do |di|
          ni = clampi(i + di, n)
          [-1, 0, 1].each do |dj|
            nj = clampi(j + dj, n)
            acc += K[(di + 1) * 3 + (dj + 1)] * src[ni * n + nj]
          end
        end
        dst[i * n + j] = acc / 16  # integer (floor) division
      end
    end
    src, dst = dst, src  # double-buffer swap
  end

  h = 0
  (n * n).times do |k|
    h = (h * 31 + src[k]) % P
  end
  h
end

n = ARGV[0] ? ARGV[0].to_i : 256
puts blur(n)
puts "blur(#{n})"
