using DelimitedFiles

function read_vector(doc::String, n::Int)
    vector = Array{Int, 1}()
    data = readdlm(doc, skipstart=n)
    for i in data[1,:]
        append!(vector, i)
    end
    return(n+1, vector)
end

function read_matrix(P::Int, Q::Int, doc::String, n::Int)
    matrix = zeros(Int, P, Q)
    data = readdlm(doc, skipstart=n)
    for i = 1:P
        for j = 1:Q
            matrix[i,j] = data[i,j]
        end
    end
    return(n+P, matrix)
end

function read_initial_data(doc::String)
    open(doc, "r") do f
        n = 8
        C = parse(Int, readline(f)) #number of containers
        P = parse(Int, readline(f)) #number of positions
        CP = parse(Int, readline(f)) #number of compatible combinations
        S = parse(Int, readline(f)) #number of transport vehicles
        Q = parse(Int, readline(f)) #number of quay cranes
        mt = parse(Int, readline(f)) #maximum time
        beta = parse(Int, readline(f)) #beta
        EFT = parse(Int, readline(f)) #Expected Finishing Time

        n, ci = read_vector(doc, n) #container class vector
        n, pj = read_vector(doc, n) #position class vector

        n, qj = read_matrix(P,Q,doc,n) #quay cranes position matrix
        n, sj = read_matrix(P,S,doc,n) #transfer vehicle position matrix
        n, prejj = read_matrix(P, P, doc, n) #position precedence matrix
        n, cpij = read_matrix(CP, 3, doc ,n) #combination c, p, time(cp)
        return(C,P,CP,S,Q,mt,beta,EFT,ci,pj,qj,sj,prejj,cpij)
    end
end

#doc = "../data/60C_25Type_LessDense_2QC_6TV.txt"
#C,P,CP,S,Q,mt,beta,EFT,ci,pj,qj,sj,prejj,cpij = read_initial_data(doc)



function new_bays(x::Int, P::Int)
    J = 20
    l = Array{Int, 1}()
    bj = Array{Int, 1}()
    prejj = zeros(Int, P, P)
    #number of bays depending on the vessel size
    if x == 60
        J = 6
    elseif x == 240
        J = 12
    end

    for i=1:P
        for s=1:i-1
            prejj[s,i] = 1
        end
    end

    for nb = 1:J-1
        rnd = Int(floor(rand(-P/2:P/2)/J))
        push!(l, Int(floor(P/J))*nb + rnd + 1)
        for i = 1:P
            for j = 1:P
                if i <= P/J*nb + rnd  &&  j > P/J*nb + rnd
                    prejj[i,j] = 0
                end
            end
        end
    end

    print(l)
    push!(l,P)
    n=1
    bj=Array{Int,1}()
    for p = 1:P
        if p<=l[n]
            push!(bj, n)
        else
            n=n+1
            push!(bj, n)
        end
    end
    return(J, bj, prejj)
end




function write_file(output::String, C::Int,P::Int,CP::Int,Q::Int,J::Int,tt::Int,d::Int,ci::Array{Int,1},pj::Array{Int,1},bj::Array{Int,1},prejj::Array{Int,2},cpij::Array{Int,2})

    open(output, "w") do o

        println(o, string(C))
        println(o, string(P))
        println(o, string(CP))
        println(o, string(Q))
        println(o, string(J))
        println(o, string(tt))
        println(o, string(d))

        for i = 1:C
            print(o, string(ci[i])*" ")
        end
        print(o, "\n")

        for j = 1:P
            print(o, string(pj[j])*" ")
        end
        print(o, "\n")

        for j = 1:P
            print(o, string(bj[j])*" ")
        end
        print(o, "\n")

        for j = 1:P
            for i = 1:P
                print(o, string(prejj[j,i])*" ")
            end
            print(o, "\n")
        end

        for j = 1:CP
            for i = 1:3
                print(o, string(cpij[j,i])*" ")
            end
            print(o, "\n")
        end

    end

end
