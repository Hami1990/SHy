## Input: input dataset in hMetis format
# Outout: hypergraph array
function ReadInp(input)

    io = open(input, "r")

    ar  = Any[]
    while !eof(io)
        rr = zeros(Int, 0)
        ln = readline(io)
        sp = split(ln)

        for kk = 1:length(sp)
            r = parse(Int, sp[kk])
            append!(rr, r)
        end #kk
        push!(ar, rr)

    end

    ar = deleteat!(ar, 1)

    return ar

end #end of function
function ReadInpI(input)
	io = open(input, "r")
	ar = Any[]
	while !eof(io)
		rr = zeros(Int, 0)
		ln = readline(io)
		sp = split(ln, ",")

		for val in sp
			push!(rr, parse(Int, val))
		end

		push!(ar, rr)
	end
	close(io)
	return ar
end

## Input: hypergraph array
# Outout: sparse incidence matrix
function INC(ar)

    col = zeros(Int, 0)
    row = zeros(Int, 0)



    for iter = 1:length(ar)
        cc = (iter) * ones(Int, length(ar[iter]))
        rr = ar[iter]

        append!(col, cc)
        append!(row, rr)
    end

    row = row

    val = ones(Float64, length(row))

    mat = sparse(col, row, val)

    return mat
end

## Input: hypergraph array
# Output: number of nodes in hypergraph
function mxF(ar)

    mx2 = Int(0)
    aa = Int(0)

    for i =1:length(ar)

    	mx2 = max(aa, maximum(ar[i]))
    	aa = mx2

    end
    return mx2

end

## Input: hypergraph array, hyperedge weights
# Output: sparse simple graph
function StarW(ar, W)

    mx = mxF(ar)

    sz = length(ar)
    col = zeros(Int32, 0)
    val = zeros(Float32, 0)
    row = zeros(Int32, 0)

    for iter =1:length(ar)
        LN = length(ar[iter])
        cc = (iter+mx) * ones(Int, LN)
        vv = (W[iter]/LN) * ones(Int, LN)

        rr = ar[iter]
        append!(col, cc)

        append!(row, rr)

        append!(val, vv)
    end

    mat = sparse(row, col, val,mx+sz, mx+sz)

    A = mat + mat'

    return A

end


## Input: a set of random vectors, smoothing steps, star matrix, number of nodes in hypergraph
# index of the first selected smoothed vector, interval among the selected smoothed vectors, total number of smoothed vectors
# Output: a set of smoothed vectors
function Filter(rv, k, AD, mx, initial, interval, Ntot)

    sz = size(AD, 1)

    V = zeros(mx, Ntot);

    sm_vec = zeros(mx, k);

    AD = AD .* 1.0

    AD[diagind(AD, 0)] = AD[diagind(AD, 0)] .+ 0.1

    dg = sum(AD, dims = 1) .^ (-.5)

    I2 = 1:sz

    D = sparse(I2, I2, sparsevec(dg))

    on = ones(Int, length(rv))

    sm_ot = rv - ((dot(rv, on) / dot(on, on)) * on)

    sm = sm_ot ./ norm(sm_ot);

    count = 1

    for loop in 1:k

        sm = D * sm

        sm = AD * sm

        sm = D * sm

        sm_ot = sm - ((dot(sm, on) / dot(on, on)) * on)

        sm_norm = sm_ot ./ norm(sm_ot);

        sm_vec[:, loop] = sm_norm[1:mx]

    end # for loop

    V = sm_vec[:, interval:interval:end]

    return V

end #end of function



## Input: hypergraph array, and a set of smoothed vectors
# Output: hyperedge scores
function HSC(ar, SV)
    score = zeros(eltype(SV), length(ar))
    @inbounds Threads.@threads for i in eachindex(ar)
        nodes = ar[i]
        for j in axes(SV, 2)
            mx, mn = -Inf, +Inf
            for node in nodes
                x = SV[node, j]
                mx = ifelse(x > mx, x, mx)
                mn = ifelse(x < mn, x, mn)
            end
            score[i] += (mx - mn)^2
        end
    end
    return score
end

## Input: hypergraph array
# Output: an array showing the hyperedges belong to each node
function HyperNodes(ar)

    H = INC(ar)

    NH1 = Any[]

    rr1 = H.rowval

    cc1 = H.colptr

    for i = 1:size(H, 2)

        st = cc1[i]

        ed = cc1[i+1] - 1

        push!(NH1, rr1[st:ed])

    end

    return NH1

end

## Input: hypergraph array, levels of coarsening using effective resistance clustering
# Output: the cluster indices of every node
function decomposition(ar, L)

    ar_new = Any[]

    idx_mat = Any[]

    Neff = zeros(Float64, mxF(ar))

    W = ones(Float64, length(ar))

    @inbounds for loop = 1:L

        mx = mxF(ar)

        ## star expansion
        A = StarW(ar, W)

        ## computing the smoothed vectors
        initial = 0

        SmS = 300

        interval = 20

        Nrv = 1

        RedR = 1

        Nsm = Int((SmS - initial) / interval)

        Ntot = Nrv * Nsm

        Qvec = zeros(Float64, 0)

        Eratio = zeros(Float64, length(ar), Ntot)

        global SV = zeros(Float64, mx, Ntot)

        for ii = 1:Nrv

            sm = zeros(mx, Nsm)

            Random.seed!(1); randstring()

            rv = (rand(Float64, size(A, 1), 1) .- 0.5).*2

            sm = Filter(rv, SmS, A, mx, initial, interval, Nsm)

            SV[:, (ii-1)*Nsm+1 : ii*Nsm] = sm

        end

        ## Make all the smoothed vectors orthogonal to each other
        QR = qr(SV)

        SV = Matrix(QR.Q)

        ## Computing the ratios using all the smoothed vectors
        for jj = 1:size(SV, 2)

            hscore = HSC(ar, SV[:, jj])

            Eratio[:, jj] = hscore ./ sum(hscore)

        end #for jj

        ## Approximating the effective resistance of hyperedges by selecting the top ratio
        #global Evec = sum(Eratio, dims=2) ./ size(SV,2)
        E2 = sort(Eratio, dims=2, rev=true)
        Evec = E2[:, 1]

        # Adding the effective resistance of super nodes from previous levels
        @inbounds for kk = 1:length(ar)

            nd2 = ar[kk]

            Evec[kk] = Evec[kk] + sum(Neff[nd2])

        end

        ## Normalizing the ERs
        P = Evec ./ maximum(Evec)

        ## Choosing a ratio of all the hyperedges
        Nsample = round(Int, RedR * length(ar))
        if loop == 1
			println("\nNsample: $Nsample \n")
		end

        PosP = sortperm(P[:,1])

        ## Increasing the weight of the hyperedges with small ERs
        W[PosP[1:Nsample]] = W[PosP[1:Nsample]] .* (1 .+  1 ./ P[PosP[1:Nsample]])

        ## Selecting the hyperedges with higher weights for contraction
        Pos = sortperm(W, rev=true)
        #global Pos = [4,3,2,1]

        ## Hyperedge contraction
        flag = falses(mx)

        flagE = falses(length(ar))

        val = 1

        idx = zeros(Int, mx)

        Neff_new = zeros(Float64, 0)

        @inbounds for ii = 1:Nsample

            nd = ar[Pos[ii]]

            fg = flag[nd]

            fd1 = findall(x->x==0, fg)

            if length(fd1) > 1

                nd = nd[fd1]

                flagE[Pos[ii]] = 1

                idx[nd] .= val

                flag[nd] .= 1

                val +=1

                ## creating the super node weights
                new_val = Evec[Pos[ii]] + sum(Neff[nd])

                append!(Neff_new, new_val)

            end # endof if

        end #end of for ii

        ## indexing the isolated nodes
        fdz = findall(x-> x==0, idx)

        fdnz = findall(x-> x!=0, idx)

        V = vec(val:val+length(fdz)-1)

        idx[fdz] = V
        ## Adding the weight od isolated nodes
        append!(Neff_new, Neff[fdz])

        push!(idx_mat, idx)

        ## generating the coarse hypergraph
        ar_new = Any[]

        @inbounds for ii = 1:length(ar)

            nd = ar[ii]

            nd_new = unique(idx[nd])

            push!(ar_new, sort(nd_new))

        end #end of for ii

        ## Keeping the edge weights of non unique elements
        fdnu = unique(z -> ar_new[z], 1:length(ar_new))
        W2 = W[fdnu]


        ## removing the repeated hyperedges
        ar_new = unique(ar_new)

        ### removing hyperedges with cardinality of 1
        HH = INC(ar_new)
        ss = sum(HH, dims=2)
        fd1 = findall(x->x==1, ss[:,1])
        deleteat!(ar_new, fd1)
        deleteat!(W2,fd1)

        ar = ar_new

        Neff = Neff_new

        W = W2

    end #end for loop

    return ar, idx_mat, SV
end


## Write the output matrix in hMETIS format
function Whgr(input, ar)
    mx = mxF(ar)
    open(input,"w")do io
        println(io, length(ar)," ", mx)
        for i =1:length(ar)
            nds = ar[i]
            for j =1:length(nds)
                print(io, nds[j], " ")
            end
            println(io)
        end
    end
end

## The output file shows the cluster that every nodes belong to it
# function CLidx(idx_mat)
#     V = 1:maximum(idx_mat[end])
#     for ii = 1:length(idx_mat)
#         idx1 = idx_mat[end - ii + 1]
#         V = V[idx1]
#     end
#     open("ibm01_idx","w")do io
#         for ii = 1:length(V)
#             println(io, V[ii])
#         end
#     end
# end

function CLidx(idx_mat)
	V = 1:maximum(idx_mat[end])
	for ii ∈ 1:length(idx_mat)
		idx1 = idx_mat[end-ii+1]
		idx1 = filter(index -> index <= length(V), idx1)
		if isempty(idx1)  # Check if idx1 becomes empty to avoid errors
			break
		end
		V = V[idx1]
	end
	open("ibm010101_idx", "w") do io
		for ii ∈ 1:length(V)
			println(io, V[ii])
		end
	end
	return V
end
