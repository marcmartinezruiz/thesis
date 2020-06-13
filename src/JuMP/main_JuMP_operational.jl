using Distributed, DelimitedFiles, JuMP, Gurobi, Statistics, StatsBase
include("../basics/init.jl")
include("../input_data/read_data.jl")
include("../input_data/data_manipulation.jl")
include("../basics/basic_functions.jl")
include("../basics/validations.jl")
include("../heuristics/indicators.jl")
include("../heuristics/construction_algorithms.jl")
include("../heuristics/local_search.jl")
include("./JuMP_functions.jl")
include("./JuMP_models.jl")
include("../solution_methods/GRASP_algorithm.jl")
include("../output_data/results.jl")

for file in reverse(readdir("../../data/Benchmark/"))
#for file in reverse(readdir("./data/pending/"))
    println("-------------")
    println(file)
    # if file != ".ipynb_checkpoints" && file != "00_DataDescription.txt"
    if file == "240C_60Type_Scattered_2QC.txt"
        doc = "../../data/Benchmark/"*file
        C,P,CP,Q,J,tt,d,ci,pj,bj,prejj,cpij = read_data(doc)

        possible_tasks = Array{LTask, 1}()
        tasks_by_position = Dict{Int, Array{LTask, 1}}()
        prec = Dict{Int, Array}()
        task_times = zeros(Int, P, C)

        for p = 1:P
            l=Array{LTask,1}()
            for t=1:CP
                target_bay = bj[cpij[t,1]+1]
                if p==P
                    #create array with all tasks
                    push!(possible_tasks, LTask(cpij[t,1]+1, target_bay, cpij[t,2]+1, cpij[t,3]))
                    #create matrix with all task times
                    task_times[cpij[t,1]+1, cpij[t,2]+1] = cpij[t,3]
                end
                #create dict with the tasks sorted by position
                if cpij[t,1]+1==p
                    push!(l,LTask(cpij[t,1]+1, target_bay, cpij[t,2]+1, cpij[t,3]))
                end
            end
            tasks_by_position[p]=sort!(l, by=x->x.t)

            #create dict with the position precedences
            s=Array{Int,1}()
            for j = 1:P
                if prejj[p,j]==1
                    push!(s,j)
                end
            end
            prec[p]=s

        end

        H = horizon_plan_new(C,P,J,Q,tt,d,bj,tasks_by_position)
        global CTS = Constants(C,P,J,Q,H,tt,d)
        global makespan, sol_x, sol_w
        #get minimum LoadingTime
        start = time()
        tasks_by_w = OperationalShippingProblem(0, task_times, bj, CTS)
        LT_min=0
        for (key,value) in tasks_by_w
            LT_min += value.t
        end
        println(LT_min)
        LB = round((2*LT_min + CTS.tt*(maximum(bj)-minimum(bj)-1))/CTS.Q)
        # print("LT_min ="), print(LT_min), print(",  LB ="), println(LB)
        print("LB ="), println(LB)
        print("UB (H) ="), println(CTS.H)
        # start = time()
        # makespan, sol_x, sol_w = FlexibleShipLoadingProblem(1, 0, prec, task_times, bj, LB, CTS)
        exec_time = time() - start
        # println(makespan)
        println(exec_time)
    end
end
