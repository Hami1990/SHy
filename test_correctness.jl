using Statistics
using SparseArrays
using Random
using LinearAlgebra
using Base.Threads

# =============================================================================
# ORIGINAL IMPLEMENTATION
# =============================================================================

function CliqueSampler_original(hyperedge::Vector{Int}, edge_weights::Float64; sample_num::Int = 1)
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
                    new_edeg_weights =
                        node_weights[i] * (total_weights - cumulative_sum[i]) /
                        total_weights / sample_num

                    r = rand() * (total_weights - cumulative_sum[i]) + cumulative_sum[i]
                    j = searchsortedfirst(cumulative_sum, r, 1, len, o)

                    i_node = hyperedge[i]
                    j_node = hyperedge[j]

                    if i_node > j_node
                        temp = j_node
                        j_node = i_node
                        i_node = temp
                    end

                    push!(I, i_node)
                    push!(J, j_node)
                    push!(V, new_edeg_weights)
                end
            end
        end
    end

    return I, J, V
end

function CliqueSampling4_original(ar, W, mx)
    I_list = zeros(Int64, 0)
    J_list = zeros(Int64, 0)
    V_list = zeros(Float32, 0)
    
    for i = 1:length(ar)
        ax = length(ar[i])
        if ax < 1250
            sample_num = ceil(Int32, 0.08 * ax)
            sample_num = max(sample_num, 1)
        else
            sample_num = 100
        end
        I, J, V = CliqueSampler_original(ar[i], W[i]; sample_num = sample_num)
        append!(I_list, I)
        append!(J_list, J)
        append!(V_list, V)
    end
    
    adj = sparse(I_list, J_list, V_list, mx, mx)
    AC = adj + adj'
    return AC
end

# =============================================================================
# ALTERNATE IMPLEMENTATION (from user)
# =============================================================================

const SAMPLING_RATE = 0.08
const MAX_SAMPLES = 100
const LARGE_EDGE_SAMPLES_THRESHOLD = 1250
const LARGE_THRESHOLD = 10000

@inline function get_sample_num(len::Int)
    if len < LARGE_EDGE_SAMPLES_THRESHOLD
        return max(ceil(Int, SAMPLING_RATE * len), 1)
    else
        return MAX_SAMPLES
    end
end

function sample_hyperedge_symmetric!(
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
            
            I[idx] = ni; J[idx] = nj; V[idx] = new_edge_weights
            idx += 1
            I[idx] = nj; J[idx] = ni; V[idx] = new_edge_weights
            idx += 1
        end
    end
end

function CliqueSampling_alternate(ar::Vector{Vector{Int}}, W::Vector{Float64}, mx::Int)
    n_edges = length(ar)
    
    # Pre-allocate
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
    
    # Sample all edges
    for i = 1:n_edges
        len = length(ar[i])
        sample_num = get_sample_num(len)
        sample_hyperedge_symmetric!(I_all, J_all, V_all, edge_offsets[i], ar[i], W[i], sample_num)
    end
    
    # Build sparse matrix (using standard sparse for comparison)
    A = sparse(I_all, J_all, V_all, mx, mx)
    return A
end

# =============================================================================
# CORRECTNESS TESTING
# =============================================================================

function test_single_hyperedge()
    println("="^70)
    println("Testing single hyperedge sampling correctness")
    println("="^70)
    
    Random.seed!(42)
    hyperedge = [1, 3, 5, 7, 9]
    edge_weight = 1.0
    sample_num = 3
    
    # Original
    Random.seed!(42)
    I_orig, J_orig, V_orig = CliqueSampler_original(hyperedge, edge_weight; sample_num=sample_num)
    
    # Alternate - need to collect results
    Random.seed!(42)
    len = length(hyperedge)
    triplets = 2 * sample_num * (len - 1)
    I_alt = Vector{Int}(undef, triplets)
    J_alt = Vector{Int}(undef, triplets)
    V_alt = Vector{Float64}(undef, triplets)
    sample_hyperedge_symmetric!(I_alt, J_alt, V_alt, 1, hyperedge, edge_weight, sample_num)
    
    println("\nOriginal output:")
    println("  I: $I_orig")
    println("  J: $J_orig")
    println("  V: $V_orig")
    
    println("\nAlternate output:")
    println("  I: $I_alt")
    println("  J: $J_alt")
    println("  V: $V_alt")
    
    # Check: Original produces unsorted pairs, alternate produces symmetric pairs
    # Original: (i,j) where i < j
    # Alternate: (i,j) and (j,i) pairs
    
    # Convert original to symmetric
    I_orig_sym = vcat(I_orig, J_orig)
    J_orig_sym = vcat(J_orig, I_orig)
    V_orig_sym = vcat(V_orig, V_orig)
    
    # Sort both for comparison
    orig_pairs = [(I_orig_sym[i], J_orig_sym[i], V_orig_sym[i]) for i in 1:length(I_orig_sym)]
    alt_pairs = [(I_alt[i], J_alt[i], V_alt[i]) for i in 1:length(I_alt)]
    
    sort!(orig_pairs)
    sort!(alt_pairs)
    
    println("\nComparison:")
    println("  Original (symmetric): $(length(orig_pairs)) pairs")
    println("  Alternate: $(length(alt_pairs)) pairs")
    
    if length(orig_pairs) == length(alt_pairs)
        println("  ✓ Lengths match")
    else
        println("  ✗ Lengths differ!")
        return false
    end
    
    # Check if pairs match (allowing for floating point differences)
    all_match = true
    for i in 1:min(length(orig_pairs), length(alt_pairs))
        if orig_pairs[i][1] != alt_pairs[i][1] || orig_pairs[i][2] != alt_pairs[i][2]
            println("  ✗ Pair mismatch at index $i: orig=$(orig_pairs[i][1:2]), alt=$(alt_pairs[i][1:2])")
            all_match = false
        elseif abs(orig_pairs[i][3] - alt_pairs[i][3]) > 1e-10
            println("  ✗ Value mismatch at index $i: orig=$(orig_pairs[i][3]), alt=$(alt_pairs[i][3])")
            all_match = false
        end
    end
    
    if all_match
        println("  ✓ All pairs match!")
    end
    
    return all_match
end

function test_edge_case_len2()
    println("\n" * "="^70)
    println("Testing edge case: hyperedge of length 2")
    println("="^70)
    
    Random.seed!(42)
    hyperedge = [1, 5]
    edge_weight = 1.0
    
    # Original
    Random.seed!(42)
    I_orig, J_orig, V_orig = CliqueSampler_original(hyperedge, edge_weight; sample_num=1)
    
    # Alternate
    Random.seed!(42)
    I_alt = Vector{Int}(undef, 2)
    J_alt = Vector{Int}(undef, 2)
    V_alt = Vector{Float64}(undef, 2)
    sample_hyperedge_symmetric!(I_alt, J_alt, V_alt, 1, hyperedge, edge_weight, 1)
    
    println("\nOriginal: I=$I_orig, J=$J_orig, V=$V_orig")
    println("Alternate: I=$I_alt, J=$J_alt, V=$V_alt")
    
    # Original produces one pair (sorted), alternate produces symmetric pair
    orig_sym = [(I_orig[1], J_orig[1], V_orig[1]), (J_orig[1], I_orig[1], V_orig[1])]
    alt_sym = [(I_alt[1], J_alt[1], V_alt[1]), (I_alt[2], J_alt[2], V_alt[2])]
    
    sort!(orig_sym)
    sort!(alt_sym)
    
    match = orig_sym == alt_sym
    if match
        println("  ✓ Length-2 case matches!")
    else
        println("  ✗ Length-2 case differs!")
    end
    
    return match
end

function test_full_matrix(ar, W, mx)
    println("\n" * "="^70)
    println("Testing full matrix construction")
    println("="^70)
    
    Random.seed!(42)
    A_orig = CliqueSampling4_original(ar, W, mx)
    
    Random.seed!(42)
    A_alt = CliqueSampling_alternate(ar, W, mx)
    
    println("\nOriginal matrix:")
    println("  Size: $(size(A_orig))")
    println("  nnz: $(nnz(A_orig))")
    
    println("\nAlternate matrix:")
    println("  Size: $(size(A_alt))")
    println("  nnz: $(nnz(A_alt))")
    
    # Compare matrices
    if size(A_orig) != size(A_alt)
        println("  ✗ Sizes differ!")
        return false
    end
    
    # Get all non-zero entries
    orig_rows, orig_cols, orig_vals = findnz(A_orig)
    alt_rows, alt_cols, alt_vals = findnz(A_alt)
    
    # Create dictionaries for comparison
    orig_dict = Dict((orig_rows[i], orig_cols[i]) => orig_vals[i] for i in 1:length(orig_rows))
    alt_dict = Dict((alt_rows[i], alt_cols[i]) => alt_vals[i] for i in 1:length(alt_rows))
    
    # Check all entries
    all_keys = union(keys(orig_dict), keys(alt_dict))
    mismatches = []
    
    for key in all_keys
        orig_val = get(orig_dict, key, 0.0)
        alt_val = get(alt_dict, key, 0.0)
        if abs(orig_val - alt_val) > 1e-6
            push!(mismatches, (key, orig_val, alt_val))
        end
    end
    
    if isempty(mismatches)
        println("  ✓ Matrices match exactly!")
        return true
    else
        println("  ✗ Found $(length(mismatches)) mismatches:")
        for (key, ov, av) in mismatches[1:min(10, length(mismatches))]
            println("    $key: orig=$ov, alt=$av, diff=$(abs(ov-av))")
        end
        return false
    end
end

# =============================================================================
# MAIN TEST
# =============================================================================

function main()
    println("\n" * "="^70)
    println("CORRECTNESS ANALYSIS")
    println("="^70)
    
    # Test 1: Single hyperedge
    test1 = test_single_hyperedge()
    
    # Test 2: Length-2 edge case
    test2 = test_edge_case_len2()
    
    # Test 3: Small full example
    println("\n" * "="^70)
    println("Testing with small example")
    println("="^70)
    
    ar = [[1, 2, 3], [2, 3, 4], [1, 4]]
    W = [1.0, 1.0, 1.0]
    mx = 4
    
    test3 = test_full_matrix(ar, W, mx)
    
    println("\n" * "="^70)
    println("SUMMARY")
    println("="^70)
    println("Single hyperedge test: $(test1 ? "PASS" : "FAIL")")
    println("Length-2 edge case: $(test2 ? "PASS" : "FAIL")")
    println("Full matrix test: $(test3 ? "PASS" : "FAIL")")
    println("="^70)
    
    return test1 && test2 && test3
end

main()
