# Test script to compare original and alternate implementations
# Run with: julia test_comparison.jl

using SparseArrays
using Random
using LinearAlgebra

# Include both implementations (simplified versions for testing)
include("original_impl.jl")
include("alternate_impl.jl")

function compare_matrices(A_orig, A_alt, tolerance=1e-6)
    println("\n" * "="^70)
    println("Matrix Comparison")
    println("="^70)
    
    # Basic properties
    println("\nOriginal matrix:")
    println("  Size: $(size(A_orig))")
    println("  nnz: $(nnz(A_orig))")
    println("  Is symmetric: $(issymmetric(A_orig))")
    
    println("\nAlternate matrix:")
    println("  Size: $(size(A_alt))")
    println("  nnz: $(nnz(A_alt))")
    println("  Is symmetric: $(issymmetric(A_alt))")
    
    # Size check
    if size(A_orig) != size(A_alt)
        println("\n❌ SIZES DIFFER!")
        return false
    end
    
    # nnz check
    if nnz(A_orig) != nnz(A_alt)
        println("\n⚠️  Non-zero counts differ: $(nnz(A_orig)) vs $(nnz(A_alt))")
    end
    
    # Symmetry check
    if !issymmetric(A_orig)
        println("\n⚠️  Original matrix is not symmetric!")
    end
    if !issymmetric(A_alt)
        println("\n⚠️  Alternate matrix is not symmetric!")
    end
    
    # Entry-by-entry comparison
    println("\nComparing entries...")
    orig_rows, orig_cols, orig_vals = findnz(A_orig)
    alt_rows, alt_cols, alt_vals = findnz(A_alt)
    
    # Create dictionaries
    orig_dict = Dict((orig_rows[i], orig_cols[i]) => orig_vals[i] for i in 1:length(orig_rows))
    alt_dict = Dict((alt_rows[i], alt_cols[i]) => alt_vals[i] for i in 1:length(alt_rows))
    
    # Find mismatches
    all_keys = union(keys(orig_dict), keys(alt_dict))
    mismatches = []
    missing_in_alt = []
    missing_in_orig = []
    
    for key in all_keys
        orig_val = get(orig_dict, key, 0.0)
        alt_val = get(alt_dict, key, 0.0)
        diff = abs(orig_val - alt_val)
        
        if diff > tolerance
            if orig_val == 0.0
                push!(missing_in_orig, (key, alt_val))
            elseif alt_val == 0.0
                push!(missing_in_alt, (key, orig_val))
            else
                push!(mismatches, (key, orig_val, alt_val, diff))
            end
        end
    end
    
    # Report results
    if isempty(mismatches) && isempty(missing_in_alt) && isempty(missing_in_orig)
        println("  ✅ All entries match (within tolerance $tolerance)")
        return true
    else
        println("\n❌ Found differences:")
        if !isempty(mismatches)
            println("  Value mismatches: $(length(mismatches))")
            for (key, ov, av, diff) in mismatches[1:min(10, length(mismatches))]
                println("    $key: orig=$ov, alt=$av, diff=$diff")
            end
        end
        if !isempty(missing_in_alt)
            println("  Missing in alternate: $(length(missing_in_alt))")
            for (key, val) in missing_in_alt[1:min(5, length(missing_in_alt))]
                println("    $key: value=$val")
            end
        end
        if !isempty(missing_in_orig)
            println("  Extra in alternate: $(length(missing_in_orig))")
            for (key, val) in missing_in_orig[1:min(5, length(missing_in_orig))]
                println("    $key: value=$val")
            end
        end
        return false
    end
end

function test_small_example()
    println("\n" * "="^70)
    println("Test 1: Small Example")
    println("="^70)
    
    Random.seed!(42)
    ar = [[1, 2, 3], [2, 3, 4], [1, 4]]
    W = [1.0, 1.0, 1.0]
    mx = 4
    
    println("\nInput:")
    println("  Hyperedges: $ar")
    println("  Weights: $W")
    println("  Max vertex: $mx")
    
    Random.seed!(42)
    A_orig = CliqueSampling4_original(ar, W, mx)
    
    Random.seed!(42)
    A_alt = CliqueSampling_alternate(ar, W, mx)
    
    return compare_matrices(A_orig, A_alt)
end

function test_len2_case()
    println("\n" * "="^70)
    println("Test 2: Length-2 Hyperedges")
    println("="^70)
    
    Random.seed!(42)
    ar = [[1, 2], [3, 4], [1, 3]]
    W = [1.0, 1.0, 1.0]
    mx = 4
    
    println("\nInput:")
    println("  Hyperedges: $ar (all length 2)")
    
    Random.seed!(42)
    A_orig = CliqueSampling4_original(ar, W, mx)
    
    Random.seed!(42)
    A_alt = CliqueSampling_alternate(ar, W, mx)
    
    return compare_matrices(A_orig, A_alt)
end

function main()
    println("="^70)
    println("CORRECTNESS TESTING: Original vs Alternate Implementation")
    println("="^70)
    
    test1 = test_small_example()
    test2 = test_len2_case()
    
    println("\n" * "="^70)
    println("SUMMARY")
    println("="^70)
    println("Test 1 (Small example): $(test1 ? "✅ PASS" : "❌ FAIL")")
    println("Test 2 (Length-2 case): $(test2 ? "✅ PASS" : "❌ FAIL")")
    println("="^70)
    
    if test1 && test2
        println("\n✅ All tests passed! Implementations appear equivalent.")
    else
        println("\n❌ Some tests failed. Review differences above.")
    end
end

main()
