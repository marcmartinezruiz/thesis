function write_results(doc::String, it_results::Array{Tuple{Number, Number, String, String}, 1})

    output = "./results"*doc[17:end-4]*"_results.txt"
    open(output, "w") do o

        println(o, string("makespan time indicator criteria"))
        for it in it_results
            println(o, string(it[1])*" "*string(it[2])*" "*string(it[3])*" "*string(it[4]))
        end

    end

end
