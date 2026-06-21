# gbdt: gradient-boosted decision-tree ensemble inference — the dominant tabular-ML
# algorithm (XGBoost/LightGBM/CatBoost style). B=200 trees of depth D=8 over F=8
# features. Each tree is a flat complete binary tree (NODES=511): internal nodes
# 0..254 store a (feature-index, threshold) split; leaves 255..510 store a value.
# Children of node k: left=2k+1, right=2k+2. Inference: for each sample, traverse
# all B trees (exactly D compare-and-branch steps each) and sum the leaf values.
# Checksum: poly-hash of (acc+1) per sample; secondary = sum of acc values mod P.
# LCG draw order pinned: feat then thr per internal node, leafval per leaf, samples.
# All integer — no float, no ML/tree library.

P          = 1000000007
D          = 8
B          = 200
F          = 8
NODES      = 511  # 2^(D+1) - 1
LEAF_START = 255  # 2^D - 1

def gbdt(n)
  feat    = Array.new(B * NODES, 0)
  thr     = Array.new(B * NODES, 0)
  leafval = Array.new(B * NODES, 0)

  state = 42
  B.times do |b|
    base = b * NODES
    LEAF_START.times do |node|
      state = (state * 1103515245 + 12345) & 0x7fffffff
      feat[base + node] = state % F
      state = (state * 1103515245 + 12345) & 0x7fffffff
      thr[base + node]  = state % 256
    end
    (LEAF_START...NODES).each do |node|
      state = (state * 1103515245 + 12345) & 0x7fffffff
      leafval[base + node] = state % 10
    end
  end

  sample = Array.new(n * F, 0)
  (n * F).times do |i|
    state = (state * 1103515245 + 12345) & 0x7fffffff
    sample[i] = state % 256
  end

  h     = 0
  total = 0
  n.times do |i|
    sbase = i * F
    acc   = 0
    B.times do |b|
      tbase = b * NODES
      node  = 0
      D.times do
        if sample[sbase + feat[tbase + node]] <= thr[tbase + node]
          node = 2 * node + 1
        else
          node = 2 * node + 2
        end
      end
      acc += leafval[tbase + node]
    end
    h     = (h * 31 + acc + 1) % P
    total = (total + acc)       % P
  end
  [h, total]
end

n = ARGV[0] ? ARGV[0].to_i : 5000
h, total = gbdt(n)
puts h
puts "gbdt(#{n}) = #{total}"
