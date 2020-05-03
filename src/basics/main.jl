using DelimitedFiles, JuMP, Gurobi, Statistics, StatsBase
include("./init.jl")
include("../input_data/read_data.jl")
include("../input_data/data_manipulation.jl")
include("./basic_functions.jl")
include("./validations.jl")
include("../heuristics/indicators.jl")
include("../heuristics/construction_algorithms.jl")
include("../heuristics/local_search.jl")
include("../JuMP/JuMP_functions.jl")
include("../JuMP/JuMP_models.jl")
include("../solution_methods/GRASP_algorithm.jl")
include("../output_data/results.jl")

#Read Data
    #ATOM
    #doc = "./data/Benchmark/60C_10Type_LessDense_2QC.txt"
    #doc = "./data/Benchmark/240C_20Type_LessDense_2QC.txt"
    #doc = "./data/Benchmark/500C_100Type_LessDense_4QC.txt"
    #doc = "./data/Benchmark/1000C_100Type_UniformDense_4QC.txt"
    #JUPYTER
    #doc = "../data/Benchmark/240C_20Type_LessDense_2QC.txt"

for file in reverse(readdir("./data/Benchmark/"))
#for file in reverse(readdir("./data/pending/"))
    println("-------------")
    println(file)
    if file != ".ipynb_checkpoints" && file != "00_DataDescription.txt"
    # if file == "60C_25Type_UniformDense_2QC.txt"
        doc = "./data/Benchmark/"*file
        C,P,CP,Q,J,tt,d,ci,pj,bj,prejj,cpij = read_data(doc)

        possible_tasks = Array{Task, 1}()
        tasks_by_position = Dict{Int, Array{Task, 1}}()
        prec = Dict{Int, Array}()
        task_times = zeros(Int, P, C)

        for p = 1:P
            l=Array{Task,1}()
            for t=1:CP
                target_bay = bj[cpij[t,1]+1]
                if p==P
                    #create array with all tasks
                    push!(possible_tasks, Task(cpij[t,1]+1, target_bay, cpij[t,2]+1, cpij[t,3]))
                    #create matrix with all task times
                    task_times[cpij[t,1]+1, cpij[t,2]+1] = cpij[t,3]
                end
                #create dict with the tasks sorted by position
                if cpij[t,1]+1==p
                    push!(l,Task(cpij[t,1]+1, target_bay, cpij[t,2]+1, cpij[t,3]))
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

        H = horizon_plan(C,P,J,Q,tt,d,tasks_by_position)
        CTS = Constants(C,P,J,Q,H,tt,d)

        it_results, best_makespan, best_LS = GRASP_algorithm(0, prec, task_times, bj, CTS)
        write_results(doc, it_results)
        # best_makespan, best_LS = GRASP_algorithm(0, prec, task_times, bj, CTS)
        # println(best_makespan)
        # println(best_LS)
        # plot_solution(best_LS, best_makespan, CTS)
    end
end





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
