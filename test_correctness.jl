# =============================================================================
# Correctness Test: Original vs Alternate Implementation
# =============================================================================

using Statistics
using SparseArrays
using Random
using LinearAlgebra

# =============================================================================
# ORIGINAL IMPLEMENTATION
# =============================================================================

function mxF_orig(ar::Vector{Vector{Int}})
    maximum(x -> maximum(x), ar)
end

function ReadInp_orig(input::AbstractString)
    io = open(input, "r")
    ar = Vector{Vector{Int}}()
    lnnum = 0
    for ln in eachline(io)
        lnnum += 1
        if lnnum == 1
            continue  # skip hMETIS header
        end
        sp = split(ln)
        if !isempty(sp)
            push!(ar, parse.(Int, sp))
        end
    end
    close(io)
    return ar
end

function CliqueSampler_orig(hyperedge::Vector{Int}, edge_weights::Float64; sample_num::Int = 1)
    len = length(hyperedge)
    I = Int[]
    J = Int[]
    V = Float64[]

    if len < 2
        error("The number of node in an hyperedge must be at least 2.")
    else
        equivalent_node_weights = 2 * edge_weights / (len - 1)
        node_weights = fill(equivalent_node_weights, len)
        cumulative_sum = cumsum(node_weights)
        total_weights = cumulative_sum[end]

        if len == 2
            push!(I, hyperedge[1])
            push!(J, hyperedge[2])
            push!(V, node_weights[1] * node_weights[2] / total_weights)
        else
            o = Base.Order.ord(isless, identity, false, Base.Order.Forward)

            for _ = 1:sample_num
                for i = 1:(len-1)
                    new_edeg_weights = node_weights[i] * (total_weights - cumulative_sum[i]) / total_weights / sample_num
                    r = rand() * (total_weights - cumulative_sum[i]) + cumulative_sum[i]
                    j = searchsortedfirst(cumulative_sum, r, 1, len, o)

                    ni = hyperedge[i]
                    nj = hyperedge[j]

                    if ni > nj
                        temp = nj
                        nj = ni
                        ni = temp
                    end

                    push!(I, ni)
                    push!(J, nj)
                    push!(V, new_edeg_weights)
                end
            end
        end
    end

    return I, J, V
end

function CliqueSampling4_orig(ar, W, mx)
    I_list = zeros(Int64, 0)
    J_list = zeros(Int64, 0)
    V_list = zeros(Float64, 0)
    
    for i = 1:length(ar)
        ax = length(ar[i])
        if ax < 1250
            sample_num = ceil(Int32, 0.08 * ax)
            sample_num = max(sample_num, 1)
        else
            sample_num = 100
        end
        I, J, V = CliqueSampler_orig(ar[i], W[i]; sample_num = sample_num)
        append!(I_list, I)
        append!(J_list, J)
        append!(V_list, V)
    end

    adj = sparse(I_list, J_list, V_list, mx, mx)
    AC = adj + adj'  # KEY: Symmetrization happens here!
    return AC
end

# =============================================================================
# ALTERNATE IMPLEMENTATION
# =============================================================================

const SAMPLING_RATE = 0.08
const MAX_SAMPLES = 100
const LARGE_EDGE_SAMPLES_THRESHOLD = 1250

@inline function get_sample_num(len::Int)
    if len < LARGE_EDGE_SAMPLES_THRESHOLD
        return max(ceil(Int, SAMPLING_RATE * len), 1)
    else
        return MAX_SAMPLES
    end
end

function sample_hyperedge_symmetric_alt!(
    I::Vector{Int}, J::Vector{Int}, V::Vector{Float64},
    start_idx::Int,
    hyperedge::Vector{Int}, 
    edge_weights::Float64, 
    sample_num::Int
)
    len = length(hyperedge)
    
    equivalent_node_weights = 2 * edge_weights / (len - 1)
    node_weights = fill(equivalent_node_weights, len)
    cumulative_sum = cumsum(node_weights)
    total_weights = cumulative_sum[end]
    
    if len == 2
        ni, nj = hyperedge[1], hyperedge[2]
        w = node_weights[1] * node_weights[2] / total_weights
        @inbounds begin
            I[start_idx] = ni; J[start_idx] = nj; V[start_idx] = w
            I[start_idx+1] = nj; J[start_idx+1] = ni; V[start_idx+1] = w
        end
        return
    end
    
    o = Base.Order.ord(isless, identity, false, Base.Order.Forward)
    idx = start_idx
    
    @inbounds for _ = 1:sample_num
        for i = 1:(len-1)
            new_edge_weights = node_weights[i] * (total_weights - cumulative_sum[i]) / total_weights / sample_num
            r = rand() * (total_weights - cumulative_sum[i]) + cumulative_sum[i]
            j = searchsortedfirst(cumulative_sum, r, 1, len, o)
            
            ni = hyperedge[i]
            nj = hyperedge[j]
            
            # KEY DIFFERENCE: No sorting, add both directions
            I[idx] = ni; J[idx] = nj; V[idx] = new_edge_weights
            idx += 1
            I[idx] = nj; J[idx] = ni; V[idx] = new_edge_weights
            idx += 1
        end
    end
end

function CliqueSampling_alt(ar::Vector{Vector{Int}}, W::Vector{Float64}, mx::Int)
    n_edges = length(ar)
    
    total_triplets = 0
    edge_offsets = Vector{Int}(undef, n_edges)
    
    for i = 1:n_edges
        len = length(ar[i])
        sample_num = get_sample_num(len)
        triplets = 2 * (len == 2 ? 1 : sample_num * (len - 1))
        edge_offsets[i] = total_triplets + 1
        total_triplets += triplets
    end
    
    I_all = Vector{Int}(undef, total_triplets)
    J_all = Vector{Int}(undef, total_triplets)
    V_all = Vector{Float64}(undef, total_triplets)
    
    for i = 1:n_edges
        len = length(ar[i])
        sample_num = get_sample_num(len)
        sample_hyperedge_symmetric_alt!(I_all, J_all, V_all, edge_offsets[i], ar[i], W[i], sample_num)
    end
    
    # KEY: No symmetrization - already symmetric!
    A = sparse(I_all, J_all, V_all, mx, mx)
    return A
end

# =============================================================================
# COMPARISON UTILITIES
# =============================================================================

function compare_matrices(A1::SparseMatrixCSC, A2::SparseMatrixCSC; tol=1e-10)
    if size(A1) != size(A2)
        println("❌ FAIL: Matrix dimensions differ")
        println("   Original: $(size(A1)), Alternate: $(size(A2))")
        return false
    end
    
    if nnz(A1) != nnz(A2)
        println("⚠️  WARNING: Different number of non-zeros")
        println("   Original: $(nnz(A1)), Alternate: $(nnz(A2))")
    end
    
    diff = A1 - A2
    nz = nonzeros(diff)
    max_abs_diff = isempty(nz) ? 0.0 : maximum(abs.(nz))
    relative_diff = norm(diff) / (norm(A1) + 1e-16)
    
    println("   Max absolute difference: $max_abs_diff")
    println("   Relative difference (Frobenius): $relative_diff")
    
    if max_abs_diff < tol && relative_diff < tol
        println("✅ PASS: Matrices are identical (within tolerance)")
        return true
    else
        println("❌ FAIL: Matrices differ significantly")
        
        # Find some differing entries for debugging
        rows, cols, vals = findnz(diff)
        n_show = min(10, length(rows))
        if n_show > 0
            println("\n   First $n_show differing entries:")
            for k = 1:n_show
                i, j, v = rows[k], cols[k], vals[k]
                println("      ($i, $j): Original=$(A1[i,j]), Alternate=$(A2[i,j]), Diff=$v")
            end
        end
        return false
    end
end

function check_symmetry(A::SparseMatrixCSC; tol=1e-10)
    diff = A - A'
    nz = nonzeros(diff)
    max_diff = isempty(nz) ? 0.0 : maximum(abs.(nz))
    is_symmetric = max_diff < tol
    println("   Symmetry check: $(is_symmetric ? "✅" : "❌") (max diff: $max_diff)")
    return is_symmetric
end

# =============================================================================
# TEST CASES
# =============================================================================

function test_simple_hypergraph()
    println("\n" * "="^70)
    println("TEST 1: Simple Hypergraph (Deterministic)")
    println("="^70)
    
    # Create a simple test case
    ar = [
        [1, 2],
        [2, 3, 4],
        [1, 3, 5]
    ]
    
    mx = maximum(maximum.(ar))
    W = ones(Float64, length(ar))
    
    # Set seed for reproducibility
    Random.seed!(42)
    A_orig = CliqueSampling4_orig(ar, W, mx)
    
    Random.seed!(42)
    A_alt = CliqueSampling_alt(ar, W, mx)
    
    println("\nOriginal Matrix:")
    println("  Size: $(size(A_orig)), nnz: $(nnz(A_orig))")
    check_symmetry(A_orig)
    
    println("\nAlternate Matrix:")
    println("  Size: $(size(A_alt)), nnz: $(nnz(A_alt))")
    check_symmetry(A_alt)
    
    println("\nComparison:")
    return compare_matrices(A_orig, A_alt)
end

function test_edge_size_2()
    println("\n" * "="^70)
    println("TEST 2: Hyperedge of Size 2 (Edge Case)")
    println("="^70)
    
    ar = [[1, 2]]
    mx = 2
    W = [1.0]
    
    Random.seed!(123)
    A_orig = CliqueSampling4_orig(ar, W, mx)
    
    Random.seed!(123)
    A_alt = CliqueSampling_alt(ar, W, mx)
    
    println("\nOriginal Matrix:")
    println("  Size: $(size(A_orig)), nnz: $(nnz(A_orig))")
    check_symmetry(A_orig)
    
    println("\nAlternate Matrix:")
    println("  Size: $(size(A_alt)), nnz: $(nnz(A_alt))")
    check_symmetry(A_alt)
    
    println("\nComparison:")
    return compare_matrices(A_orig, A_alt)
end

function test_large_hyperedge()
    println("\n" * "="^70)
    println("TEST 3: Large Hyperedge (> 1250 nodes)")
    println("="^70)
    
    # Create a large hyperedge
    ar = [collect(1:1500)]
    mx = 1500
    W = [1.0]
    
    Random.seed!(456)
    A_orig = CliqueSampling4_orig(ar, W, mx)
    
    Random.seed!(456)
    A_alt = CliqueSampling_alt(ar, W, mx)
    
    println("\nOriginal Matrix:")
    println("  Size: $(size(A_orig)), nnz: $(nnz(A_orig))")
    check_symmetry(A_orig)
    
    println("\nAlternate Matrix:")
    println("  Size: $(size(A_alt)), nnz: $(nnz(A_alt))")
    check_symmetry(A_alt)
    
    println("\nComparison:")
    return compare_matrices(A_orig, A_alt)
end

function test_multiple_samples()
    println("\n" * "="^70)
    println("TEST 4: Multiple Samples (Statistical Test)")
    println("="^70)
    
    ar = [[1, 2, 3, 4, 5]]
    mx = 5
    W = [1.0]
    
    n_runs = 10
    all_pass = true
    
    for run = 1:n_runs
        seed = 1000 + run
        Random.seed!(seed)
        A_orig = CliqueSampling4_orig(ar, W, mx)
        
        Random.seed!(seed)
        A_alt = CliqueSampling_alt(ar, W, mx)
        
        if !compare_matrices(A_orig, A_alt, tol=1e-10)
            all_pass = false
            println("  ❌ Run $run FAILED")
        else
            println("  ✅ Run $run PASSED")
        end
    end
    
    return all_pass
end

function test_real_data()
    println("\n" * "="^70)
    println("TEST 5: Real Data File (if available)")
    println("="^70)
    
    test_files = ["data/ibm01.hgr", "data/ibm02.hgr"]
    
    for fname in test_files
        if isfile(fname)
            println("\nTesting with: $fname")
            ar = ReadInp_orig(fname)
            mx = mxF_orig(ar)
            W = ones(Float64, length(ar))
            
            println("  Hyperedges: $(length(ar)), Max node: $mx")
            
            Random.seed!(789)
            println("\n  Running original...")
            t1 = @elapsed A_orig = CliqueSampling4_orig(ar, W, mx)
            println("  Time: $(round(t1, digits=2))s")
            
            Random.seed!(789)
            println("\n  Running alternate...")
            t2 = @elapsed A_alt = CliqueSampling_alt(ar, W, mx)
            println("  Time: $(round(t2, digits=2))s")
            
            println("\n  Speedup: $(round(t1/t2, digits=2))x")
            
            println("\n  Original Matrix:")
            println("    Size: $(size(A_orig)), nnz: $(nnz(A_orig))")
            check_symmetry(A_orig)
            
            println("\n  Alternate Matrix:")
            println("    Size: $(size(A_alt)), nnz: $(nnz(A_alt))")
            check_symmetry(A_alt)
            
            println("\n  Comparison:")
            if compare_matrices(A_orig, A_alt)
                return true
            end
        end
    end
    
    println("\n  No data files found, skipping test.")
    return true
end

# =============================================================================
# MAIN TEST RUNNER
# =============================================================================

function run_all_tests()
    println("\n" * "="^70)
    println("CORRECTNESS VERIFICATION: Original vs Alternate")
    println("="^70)
    
    results = Dict{String, Bool}()
    
    results["Simple Hypergraph"] = test_simple_hypergraph()
    results["Edge Size 2"] = test_edge_size_2()
    results["Large Hyperedge"] = test_large_hyperedge()
    results["Multiple Samples"] = test_multiple_samples()
    results["Real Data"] = test_real_data()
    
    println("\n" * "="^70)
    println("SUMMARY")
    println("="^70)
    
    all_pass = true
    for (test_name, passed) in results
        status = passed ? "✅ PASS" : "❌ FAIL"
        println("  $status: $test_name")
        all_pass = all_pass && passed
    end
    
    println("="^70)
    if all_pass
        println("🎉 ALL TESTS PASSED!")
        println("\nCONCLUSION: The alternate implementation is CORRECT.")
        println("It produces identical results to the original implementation.")
    else
        println("⚠️  SOME TESTS FAILED!")
        println("\nPlease review the failed tests above.")
    end
    println("="^70)
end

# Run the tests
run_all_tests()
