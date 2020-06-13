using Distributed
@everywhere using DelimitedFiles, JuMP, Gurobi, Statistics, StatsBase, DataFrames, Gadfly
include("./init.jl")
include("../input_data/read_data.jl")
@everywhere include("../input_data/data_manipulation.jl")
@everywhere include("./basic_functions.jl")
@everywhere include("./validations.jl")
@everywhere include("../heuristics/indicators.jl")
@everywhere include("../heuristics/construction_algorithms.jl")
@everywhere include("../heuristics/local_search.jl")
include("../JuMP/JuMP_functions.jl")
include("../JuMP/JuMP_models.jl")
@everywhere include("../solution_methods/GRASP_filter_multi.jl")
# @everywhere include("../solution_methods/GRASP_local_search_multi.jl")
# @everywhere include("../solution_methods/GRASP_reactive_multi.jl")
# @everywhere include("../solution_methods/GRASP_algorithm_multi.jl")
# include("../solution_methods/GRASP_algorithm.jl")
include("../output_data/results.jl")

#Read Data
    #ATOM
    #doc = "./data/Benchmark/60C_10Type_LessDense_2QC.txt"
    #doc = "./data/Benchmark/240C_20Type_LessDense_2QC.txt"
    #doc = "./data/Benchmark/500C_100Type_LessDense_4QC.txt"
    #doc = "./data/Benchmark/1000C_100Type_UniformDense_4QC.txt"
    #JUPYTER
    #doc = "../data/Benchmark/240C_20Type_LessDense_2QC.txt"
results = Dict{String, Array{Tuple{Number, Number}, 1}}()
for i = 1:10
for file in reverse(readdir("../../data/Benchmark/"))
#for file in reverse(readdir("./data/pending/"))
    println("-------------")
    println(file)
    # if file != ".ipynb_checkpoints" && file != "00_DataDescription.txt"
    if file[1:3] != "100"
        if file[1:3] == "60C"
            if file[5:6] == "10"
                beta = -0.5
            else
                beta = 0.25
            end
        elseif file[1:3] == "240"
            if file[6:7] == "20"
                beta = -0.25
            else
                beta = 0.25
            end
        elseif file[1:3] == "500"
            if file[6:7] == "20"
                beta = 0.75
            else
                beta = -0.25
            end
        else
            if file[6:7] == "20"
                beta = 0.75
            elseif file[6:7] == "60"
                beta = 0.5
            else
                beta = 0.25
            end
        end


        doc = "../../data/Benchmark/"*file
        C,P,CP,Q,J,tt,d,ci,pj,bj,prejj,cpij = read_data(doc)

        possible_tasks = Array{LTask, 1}()
        tasks_by_position = Dict{Int, Array{LTask, 1}}()
        prec = Dict{Int, Array}()
        task_times = zeros(Int, P, C)

        for p = 1:P
            l=Array{LTask, 1}()
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

        H = horizon_plan(C,P,J,Q,tt,d,bj,tasks_by_position)
        global CTS = Constants(C,P,J,Q,H,tt,d)
        global it_results, best_makespan, best_LS, exec_time
        start = time()
        makespan_1, best_LS_1 = GRASP_multi_thread(0 , prec, task_times, bj, CTS)
        makespan_2, best_LS_2 = GRASP_multi_thread(beta , prec, task_times, bj, CTS)
        if makespan_1 < makespan_2
            best_makespan = makespan_1
            best_LS = best_LS_1
        else
            best_makespan = makespan_2
            best_LS = best_LS_2
        end
        exec_time = time() - start
        #write_results(doc, it_results)
        # write_time_results(doc, exec_time)
        # best_makespan, best_LS = GRASP_algorithm(0, prec, task_times, bj, CTS)
        println(best_makespan)
        println(exec_time)
        #println(best_LS)
        if haskey(results, file)
            push!(results[file], (best_makespan, exec_time))
        else
            results[file] = [(best_makespan, exec_time)]
        end
    end
end
end

# plot_solution(best_LS, best_makespan, CTS)


# LOCAL SEARCH OPTIMIZATION
# while true
#     global best_makespan
#     global best_LS
#     improve, best_LS, best_makespan = remove_single_moves(best_makespan, best_LS, CTS)
#     if improve == false
#         break
#     end
# end
# println(best_makespan)
# plot_solution(best_LS, best_makespan, CTS)
