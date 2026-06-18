MIN_DEPTH = 4

# Real heap node: a plain Ruby object with two child references (idiomatic),
# no node pool / arena / flat-array encoding.
class Node
  attr_accessor :left, :right

  def initialize(left, right)
    @left = left
    @right = right
  end
end

def make(depth)
  return Node.new(nil, nil) if depth == 0
  Node.new(make(depth - 1), make(depth - 1))
end

def check(node)
  return 1 if node.left.nil?
  1 + check(node.left) + check(node.right)
end

def binary_trees(n)
  max_depth = MIN_DEPTH + 2 > n ? MIN_DEPTH + 2 : n
  stretch_depth = max_depth + 1

  total = check(make(stretch_depth))
  long_lived = make(max_depth)

  depth = MIN_DEPTH
  while depth <= max_depth
    iterations = 1 << (max_depth - depth + MIN_DEPTH)
    s = 0
    iterations.times { s += check(make(depth)) }
    total += s
    depth += 2
  end

  total += check(long_lived)
  total
end

n = ARGV[0] ? ARGV[0].to_i : 14
puts binary_trees(n)
puts "binary-trees(#{n})"
