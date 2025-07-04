using Statistics
using SparseArrays
using Random
using LinearAlgebra

include("HyperEF.jl")
include("Functions.jl")

# ──────────────────────────────
# 1. Parse command-line inputs
#    USAGE: julia Run_HyperEF.jl <hypergraph_file> <L> [R]
# ──────────────────────────────
if length(ARGS) < 2
	println("""
	Usage:  julia Run_HyperEF.jl <hypergraph_file> <L> [R]

	  <hypergraph_file>   e.g. Titan05.hgr   (relative or absolute path)
	  <L>                 integer           (e.g. 1)
	  [R]                 float   (optional, default = 1.0)
	""")
	exit(1)
end

filename = ARGS[1]                                  # hypergraph file
L        = parse(Int, ARGS[2])                      # coarse-level count
R        = length(ARGS) ≥ 3 ? parse(Float64, ARGS[3]) : 1.0

# ──────────────────────────────
# 2. Locate the file (relative to this script if a bare name is given)
# ──────────────────────────────
script_dir = @__DIR__                               # directory of this script
data_file  = isabspath(filename) ? filename :
joinpath(script_dir, "..", "data", filename)

# script_dir = @__DIR__
# data_path = isabspath(hg_path) ? hg_path :
# 			joinpath(script_dir, "..", "data", hg_path)

# hg_name = basename(hg_path)         # ► Titan05.hgr  (no directories!)

# ──────────────────────────────
# 3. Read hypergraph and run HyperEF
# ──────────────────────────────
ar = ReadInp(data_file)             # <– uses your existing ReadInp()
HyperEF(ar, L, R, filename)       # <– generates the output files

