using SparseArrays
using MatrixNetworks
using LinearAlgebra
using Random

include("HyperSF.jl")
include("Functions.jl")
include("../HyperSF/include/HyperLocal.jl")
include("../HyperSF/include/Helper_Functions.jl")
include("../HyperSF/include/maxflow.jl")


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
R        = length(ARGS) ≥ 3 ? parse(Float64, ARGS[3]) : 0.1

# ──────────────────────────────
# 2. Locate the file (relative to this script if a bare name is given)
# ──────────────────────────────
script_dir = @__DIR__                               # directory of this script
data_file  = isabspath(filename) ? filename :
joinpath(script_dir, "..","data", filename)
println("$data_file")
println("$filename")
# ──────────────────────────────
# 3. Read hypergraph and run HyperEF
# ──────────────────────────────
ar = ReadInp(data_file)             # <– uses your existing ReadInp()
# HyperEF(ar, L, R, filename)       # <– generates the output files
for i in 1:L
	HyperSF(ar, i, R, filename)
end

