using DataFrames, Statistics, StatsBase

function analyze_results_stats(doc)
    df = readtable(doc, header=true, separator=' ')
    categorical!(df, :indicator)
    categorical!(df, :criteria)

    df_ind_dist = filter(r -> any(occursin.(["dist"], r.indicator)), df)
    df_ind_num = filter(r -> any(occursin.(["number"], r.indicator)), df)
    df_crit_dist = filter(r -> any(occursin.(["dist"], r.criteria)), df)
    df_crit_num = filter(r -> any(occursin.(["number"], r.criteria)), df)

    df_ind_crit_dist = filter(r -> any(occursin.(["dist"], r.indicator)), df_crit_dist)
    df_ind_crit_num = filter(r -> any(occursin.(["number"], r.indicator)), df_crit_num)


    results = Array{Array{Any, 1},1}()
    stats = summarystats(df_ind_dist[:makespan])
    t_ind_dist = [stats.mean, stats.min, stats.q25, stats.median, stats.q75, stats.max, "ind_dist"]
    push!(results, t_ind_dist)

    stats = summarystats(df_ind_num[:makespan])
    t_ind_num = [stats.mean, stats.min, stats.q25, stats.median, stats.q75, stats.max, "ind_num"]
    push!(results, t_ind_num)

    stats = summarystats(df_crit_dist[:makespan])
    t_crit_dist = [stats.mean, stats.min, stats.q25, stats.median, stats.q75, stats.max, "crit_dist"]
    push!(results, t_crit_dist)

    stats = summarystats(df_crit_num[:makespan])
    t_crit_num = [stats.mean, stats.min, stats.q25, stats.median, stats.q75, stats.max, "crit_num"]
    push!(results, t_crit_num)

    stats = summarystats(df_ind_crit_dist[:makespan])
    t_ind_crit_dist = [stats.mean, stats.min, stats.q25, stats.median, stats.q75, stats.max, "ind_crit_dist"]
    push!(results, t_ind_crit_dist)

    stats = summarystats(df_ind_crit_num[:makespan])
    t_ind_crit_num = [stats.mean, stats.min, stats.q25, stats.median, stats.q75, stats.max, "ind_crit_num"]
    push!(results, t_ind_crit_num)

    return(results)
end

function init_results_stats_file(output::String)

    open(output, "w") do o
        println(o, "Mean Minimum 1stQuartile Median 3rdQuartile Maximum Type")
    end
end

function write_results_stats_file(output::String, results::Array{Array{Any,1},1})

    open(output, "a+") do o
        for t in results
            for s in t
                print(o, string(s)*" ")
            end
            print(o, "\n")
        end
    end
end



#RESULTS MAIN PROGRAM
for file in reverse(readdir("./results/"))
    println("-------------")
    println(file)
    if file != ".ipynb_checkpoints" && file != "60C_stats.txt" && file != "240C_stats.txt" && file != "500C_stats.txt" && file != "1000C_stats.txt"
    # if file == "60C_25Type_UniformDense_2QC.txt"
        doc = "./results/"*file
        results = analyze_results_stats(doc)

        if file[1:2] == "60"
            out_doc = "60C_stats.txt"
        elseif file[1:3] == "240"
            out_doc = "240C_stats.txt"
        elseif file[1:3] == "500"
            out_doc = "500C_stats.txt"
        else
            out_doc = "1000C_stats.txt"
        end

        if !(out_doc in readdir("./results/"))
            init_results_stats_file("./results/"*out_doc)
        end

        write_results_stats_file("./results/"*out_doc, results)

    end
end
