# Random Walk Time Complexity Analysis: Graphs vs Hypergraphs

## Executive Summary

This document analyzes the time complexity of random walk algorithms in both graphs and hypergraphs, examining different methods and identifying the most efficient approaches.

### Quick Reference: Best Methods

| Scenario | Best Method | Time Complexity | Notes |
|----------|-------------|-----------------|-------|
| **Graph - Single Walk** | Node-to-node traversal | **O(k · d_avg)** | Optimal for sparse graphs |
| **Graph - Multiple/Spectral** | Matrix-based diffusion | **O(k · m)** | For PageRank, eigenvector centrality |
| **Hypergraph - Single Walk** | Star expansion + walk | **O(k · d_avg)** | Linear in hyperedge sizes |
| **Hypergraph - Spectral** | Star expansion + diffusion | **O(k · (∑\|e\| + n + m))** | Used in HyperEF/HyperSF |

**Key Insight:** Star expansion (O(∑|e|)) is always preferred over clique expansion (O(∑|e|²)) for hypergraphs.

---

## 1. Random Walks in Graphs

### 1.1 Standard Random Walk (Node-to-Node Traversal)

**Algorithm:**
- Start at a node
- At each step, randomly select a neighbor with probability proportional to edge weights
- Repeat for k steps

**Time Complexity:**
- **Per step:** O(d) where d is the degree of current node
- **k steps:** O(k · d_avg) where d_avg is average degree
- **Space:** O(1) for storing current position

**Best Case:** O(k) when d_avg = O(1) (sparse graphs)
**Worst Case:** O(k · n) when d_avg = O(n) (dense graphs)

### 1.2 Matrix-Based Random Walk (Diffusion Process)

**Algorithm:**
- Represent graph as adjacency matrix A
- Normalize: P = D^(-1) · A where D is degree matrix
- Apply: x^(t+1) = P · x^(t) for k iterations

**Time Complexity:**
- **Per iteration:** O(nnz(A)) where nnz is number of non-zeros
- **k iterations:** O(k · nnz(A))
- **Space:** O(n) for storing state vector

**For sparse graphs:** O(k · m) where m is number of edges
**For dense graphs:** O(k · n²)

### 1.3 Power Iteration Method

**Algorithm:**
- Similar to matrix-based but with normalization at each step
- Used for computing PageRank, eigenvector centrality

**Time Complexity:**
- **Per iteration:** O(nnz(A) + n) = O(nnz(A))
- **k iterations:** O(k · nnz(A))
- **Convergence:** Typically O(log n / log(1-α)) iterations for PageRank

---

## 2. Random Walks in Hypergraphs

### 2.1 Direct Hypergraph Random Walk

**Challenge:** Hypergraphs have hyperedges connecting multiple nodes, making direct random walks more complex.

**Methods:**

#### Method A: Star Expansion (Used in HyperEF/HyperSF)
- Convert hypergraph to bipartite graph: nodes + hyperedges as vertices
- Graph has n + m vertices (n nodes, m hyperedges)
- Random walk alternates between nodes and hyperedges

**Time Complexity:**
- **Graph size:** O(n + m) vertices, O(∑|e|) edges where |e| is hyperedge size
- **Per step:** O(d_avg) where d_avg is average node/hyperedge degree
- **k steps:** O(k · d_avg)
- **Space:** O(n + m)

#### Method B: Clique Expansion
- Convert each hyperedge to a clique
- Graph has n vertices, O(∑|e|²) edges

**Time Complexity:**
- **Graph construction:** O(∑|e|²) - expensive for large hyperedges
- **Random walk:** O(k · d_avg) but d_avg can be much larger
- **Space:** O(∑|e|²) - can be prohibitive

#### Method C: Weighted Clique Expansion
- Similar to clique expansion but edges weighted by 1/|e|
- Reduces impact of large hyperedges

**Time Complexity:**
- **Graph construction:** O(∑|e|²) - still expensive
- **Random walk:** O(k · d_avg)
- **Space:** O(∑|e|²)

### 2.2 Spectral Diffusion in Hypergraphs (HyperEF/HyperSF Implementation)

**Algorithm (from Filter function in codebase):**
```julia
for loop in 1:k
    sm = D * sm          # Normalize by degrees
    sm = AD * sm         # Apply adjacency matrix
    sm = D * sm          # Normalize again
    sm = normalize(sm)   # Orthogonalize
end
```

This performs: **D^(-1/2) · A · D^(-1/2)** operations (normalized Laplacian diffusion)

**Time Complexity Analysis:**

1. **Star Expansion:** O(∑|e|) to create graph with n+m vertices
2. **Matrix Construction:** O(∑|e|) for sparse adjacency matrix
3. **Per Iteration:**
   - D^(-1/2) multiplication: O(n + m)
   - A · sm multiplication: O(nnz(A)) = O(∑|e|)
   - Normalization: O(n + m)
   - **Total per iteration:** O(∑|e| + n + m)
4. **k iterations:** O(k · (∑|e| + n + m))

**Space Complexity:**
- Adjacency matrix: O(∑|e|)
- State vectors: O(n + m)
- **Total:** O(∑|e| + n + m)

---

## 3. Comparison of Methods

### 3.1 For Graphs

| Method | Time Complexity | Space | Best For |
|--------|----------------|-------|----------|
| Node-to-node walk | O(k · d_avg) | O(1) | Single walk, sparse graphs |
| Matrix-based | O(k · m) | O(n) | Multiple simultaneous walks |
| Power iteration | O(k · m) | O(n) | Stationary distribution |

**Best Method:** 
- **Single walk:** Node-to-node (O(k · d_avg))
- **Multiple walks/stationary:** Matrix-based (O(k · m))

### 3.2 For Hypergraphs

| Method | Time Complexity | Space | Notes |
|--------|----------------|-------|-------|
| Star expansion + walk | O(k · d_avg) | O(n + m) | Efficient, preserves structure |
| Clique expansion + walk | O(k · d_avg) | O(∑|e|²) | Expensive construction |
| Weighted clique + walk | O(k · d_avg) | O(∑|e|²) | Better than clique but still expensive |
| Spectral diffusion (HyperEF/SF) | O(k · (∑|e| + n + m)) | O(∑|e| + n + m) | Best for spectral properties |

**Best Method:** 
- **Single walk:** Star expansion + node-to-node walk (O(k · d_avg))
- **Spectral analysis:** Star expansion + spectral diffusion (O(k · (∑|e| + n + m)))

---

## 4. Key Insights

### 4.1 Graph Random Walks
1. **Sparse graphs (m = O(n)):** All methods are efficient, O(k · n)
2. **Dense graphs (m = O(n²)):** Matrix methods become O(k · n²)
3. **Node-to-node is optimal** for single walks on sparse graphs

### 4.2 Hypergraph Random Walks
1. **Star expansion is preferred** over clique expansion:
   - Preserves hypergraph structure
   - Linear in hyperedge sizes: O(∑|e|) vs O(∑|e|²)
   - More memory efficient

2. **Spectral diffusion (as in HyperEF/HyperSF)** is optimal for:
   - Computing effective resistances
   - Spectral clustering
   - Multiple simultaneous walks
   - Time complexity: O(k · (∑|e| + n + m)) which is linear in hypergraph size

3. **Avoid clique expansion** for large hyperedges:
   - Quadratic blowup: |e| nodes → O(|e|²) edges
   - Example: hyperedge of size 100 → 4,950 edges

### 4.3 Practical Considerations

**For the SHyPar codebase:**
- Uses **star expansion + spectral diffusion** (Filter function)
- Time complexity: O(k · (∑|e| + n + m)) per coarsening level
- With k = 300 smoothing steps, this is the dominant cost
- However, this enables effective resistance computation for high-quality partitioning

---

## 5. Optimizations

### 5.1 Early Stopping
- Use convergence criteria instead of fixed k steps
- Can reduce iterations from O(k) to O(log n) in some cases

### 5.2 Sparse Matrix Operations
- Use compressed sparse row (CSR) format
- Exploit sparsity: O(nnz) instead of O(n²)

### 5.3 Parallelization
- Matrix-vector multiplication parallelizes well
- Node-to-node walks can run multiple independent walks in parallel

### 5.4 Approximation Methods
- Monte Carlo methods: O(k · log n) for approximate PageRank
- Sketching techniques for large-scale graphs

---

## 6. Concrete Examples

### Example 1: Sparse Graph
- **Graph:** n = 10,000 nodes, m = 50,000 edges, d_avg = 10
- **Node-to-node walk (k=100):** O(100 · 10) = O(1,000) operations
- **Matrix-based (k=100):** O(100 · 50,000) = O(5,000,000) operations
- **Winner:** Node-to-node for single walk

### Example 2: Dense Graph
- **Graph:** n = 1,000 nodes, m = 500,000 edges, d_avg = 500
- **Node-to-node walk (k=100):** O(100 · 500) = O(50,000) operations
- **Matrix-based (k=100):** O(100 · 500,000) = O(50,000,000) operations
- **Winner:** Node-to-node still better for single walk

### Example 3: Hypergraph with Star Expansion
- **Hypergraph:** n = 10,000 nodes, m = 5,000 hyperedges, ∑|e| = 50,000
- **Star expansion graph:** n + m = 15,000 vertices, ∑|e| = 50,000 edges
- **Node-to-node walk (k=100):** O(100 · d_avg) ≈ O(100 · 3.3) = O(330) operations
- **Spectral diffusion (k=300):** O(300 · (50,000 + 15,000)) = O(19,500,000) operations
- **Note:** Spectral diffusion computes multiple smoothed vectors simultaneously

### Example 4: Hypergraph with Clique Expansion
- **Same hypergraph as Example 3**
- **Clique expansion:** n = 10,000 vertices, but ∑|e|² edges
- **If average hyperedge size = 10:** ∑|e|² ≈ 5,000 · 100 = 500,000 edges
- **Construction cost:** O(500,000) - already more expensive than star expansion
- **Random walk:** O(100 · 50) = O(5,000) but with much larger memory footprint
- **Winner:** Star expansion is clearly superior

---

## 7. Conclusion

**Best Methods:**

1. **Graphs - Single Walk:**
   - **O(k · d_avg)** using node-to-node traversal
   - Optimal for sparse graphs
   - **Example:** O(1,000) for k=100, d_avg=10

2. **Graphs - Multiple Walks/Spectral:**
   - **O(k · m)** using matrix-based methods
   - Optimal for computing stationary distributions
   - **Example:** O(5,000,000) for k=100, m=50,000

3. **Hypergraphs - General:**
   - **O(k · d_avg)** using star expansion + node-to-node walk
   - Best for single walks
   - **Example:** O(330) for k=100 on star-expanded graph

4. **Hypergraphs - Spectral Analysis:**
   - **O(k · (∑|e| + n + m))** using star expansion + spectral diffusion
   - Best for effective resistance, clustering (as in HyperEF/HyperSF)
   - Linear in hypergraph size, optimal for the use case
   - **Example:** O(19,500,000) for k=300, but computes multiple vectors simultaneously

**Key Takeaway:** 
- **Star expansion is the preferred method for hypergraphs**, providing linear time complexity O(∑|e|) while preserving structural properties
- **Avoid clique expansion** - it has quadratic complexity O(∑|e|²) in hyperedge sizes
- The spectral diffusion approach used in HyperEF/HyperSF achieves optimal O(k · (∑|e| + n + m)) complexity for spectral analysis tasks
- For single random walks, node-to-node traversal is always more efficient than matrix-based methods
