using DelimitedFiles

function read_vector(doc, n)
    vector = Array{Int, 1}()
    data = readdlm(doc, skipstart=n)
    for i in data[1,:]
        append!(vector, i)
    end
    return(n+1, vector)
end

function read_matrix(P, Q, doc, n)
    matrix = zeros(Int, P, Q)
    data = readdlm(doc, skipstart=n, use_mmap=true)
    for i = 1:P
        for j = 1:Q
            matrix[i,j] = data[i,j]
        end
    end
    return(n+P, matrix)
end

function read_data(doc)
    open(doc, "r") do f
        n = 7
        C = parse(Int, readline(f)) #number of containers
        P = parse(Int, readline(f)) #number of positions
        CP = parse(Int, readline(f)) #number of compatible combinations
        Q = parse(Int, readline(f)) #number of quay cranes
        J = parse(Int, readline(f)) #number of bays
        tt = parse(Int, readline(f)) #quay crane travel time per bay
        d = parse(Int, readline(f)) #clearance, in number of bays

        n, ci = read_vector(doc, n) #container class vector
        n, pj = read_vector(doc, n) #position class vector
        n, bj = read_vector(doc, n) #position class vector

        #n, qj = read_matrix(P,Q,doc,n) #quay cranes position matrix
        #n, sj = read_matrix(P,S,doc,n) #transfer vehicle position matrix
        n, prejj = read_matrix(P, P, doc, n) #position precedence matrix
        n, cpij = read_matrix(CP, 3, doc ,n) #combination c, p, time(cp)
        #return(C,P,CP,S,Q,J,tt,d,mt,beta,EFT,ci,pj,qj,sj,prejj,cpij)
        return(C,P,CP,Q,J,tt,d,ci,pj,bj,prejj,cpij)
    end
end
#doc = "../data/5C_3Type_2QC.txt"
#doc = "../data/QCSP_example.txt"
#doc = "../../data/10C_4Type_2QC.txt"
#doc = "./data/Benchmark/60C_10Type_LessDense_2QC.txt"
#doc = "./data/Benchmark/240C_20Type_LessDense_2QC.txt"
doc = "../data/Benchmark/240C_20Type_LessDense_2QC.txt"
#C,P,CP,S,Q,J,tt,d,mt,beta,EFT,ci,pj,qj,sj,prejj,cpij = read_data(doc)
C,P,CP,Q,J,tt,d,ci,pj,bj,prejj,cpij = read_data(doc)
