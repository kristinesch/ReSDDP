
import Pkg
import Revise

using Revise # Sikrer at oppdateringer av kildekode kompileres automatisk
using Pkg
Pkg.activate(@__DIR__) # Aktiverer lokalt pakkemiljø
# Pkg.resolve()
Pkg.instantiate()

using ReSDDP
using Random

import YAML

#read config and params files
config = YAML.load_file("config.yaml")
params_file = config["params_file"]
println("Reading params from ", params_file)
include(params_file)
println("Config file:    ")
println(config)

seed = 5
Random.seed!(seed)
println("Seed: ", seed)

import JuMP
import CPLEX
optimizer = JuMP.optimizer_with_attributes(
    CPLEX.Optimizer,
    #"CPX_PARAM_THREADS" => 2,
    "CPX_PARAM_SCRIND" => 0, #1 to print log
    "CPX_PARAM_PREIND" => 1,
    "CPX_PARAM_LPMETHOD" => 2 #1=primal, 2=dual, 3=network, 4=barrier
)

println("Threads available: ",Threads.nthreads())

case = config["case"]
label = config["label"]

println(case, label)

#turn on or off different steps
calculate_feasibility_cuts = true #set to false if already done, needs to be true for first run
detailed_sim = true
save_strategy_to_file = true
simulate_only = true

if (config["calculate_feasibility_cuts"] == "false")
    calculate_feasibility_cuts = false
end
if (config["detailed_sim"] == "false")
    detailed_sim = false
end
if (config["save_strategy_to_file"] == "false")
    save_strategy_to_file = false
end
if (config["simulate_only"] == "false")
    simulate_only = false
end

if LFeasCut == true
    if !LFeasPerStage == true
        label = label*"-feas1"
    else
        label = label*"-feasN"
    end
end

label = label*"-"*string(NScen)*"-"*string(NK)

#set paths to input data and result folder from config file

system = config["system"]
if (system=="win")
    case_suffix = case*"\\"
    case_suffix_res = case*label*"\\"
end
if (system=="linux")
    case_suffix = case*"/"
    case_suffix_res = case*label*"/"
end
datapath = joinpath(config["datapath"], case_suffix)
resultpath = joinpath(config["resultpath"], case_suffix_res)

mkpath(resultpath)

println("Resultpath: ", resultpath)
println("Datapath: ", datapath)
inflowdata = config["inflowdata"]
endvaluecuts = config["end_value_cuts"]

#load data
model = load(datapath, parameters, resultpath, endvaluecuts) 
inflow_model = load_inflow(datapath, model, parameters, inflowdata)

areas_with_feas_cuts = config["areas_with_feas_cuts"]

if LFeasCut == false 
    areas_with_feas_cuts = []
end

using JLD2 
using FileIO 

if simulate_only
    # Load strategy from file
    file = File(format"JLD2", joinpath(@__DIR__, case*label*"strategy.jld2"))
    println("Loading strategy from ", file)
    data = JLD2.load(file) 
    strategy = data["strategy"]

    init_val = init_system(model, parameters)

    # Load feasibility cuts from file
    file = File(format"JLD2", joinpath(@__DIR__, case*label*"feas_spaces.jld2"))

    println("Loading feasibility cuts from ", file)
    data = JLD2.load(file) 
    feas_spaces = data["feas_spaces"]

#If run the whole code
else
    # Feasibility cuts file
    file = File(format"JLD2", joinpath(@__DIR__, case*label*"feas_spaces.jld2"))

    if (calculate_feasibility_cuts)
        println("Compute feasibility cuts..")
        #feas_spaces = feasibility(model, inflow_model, parameters, datapath; optimizer=optimizer, areas_with_feas_cuts = areas_with_feas_cuts)
        if (areas_with_feas_cuts != [])
            feas_spaces = feasibility(model, inflow_model, parameters, datapath; optimizer=optimizer, areas_with_feas_cuts = areas_with_feas_cuts)
        else
            feas_spaces = feasibility(model, inflow_model, parameters, datapath; optimizer=optimizer)
        end
        println("Saving feasibility cuts to ", file)
        save(file, "feas_spaces", feas_spaces)
    end

    # Load feasibility cuts from file
    println("Loading feasibility cuts from ", file)
    data = JLD2.load(file) 
    feas_spaces = data["feas_spaces"]

    ReSDDP.print(model, parameters, true, true)

    strategy = init_strategy(model, parameters)
    init_val = init_system(model, parameters)

    #Compute strategy by SDDP
    println("Start strategy computation..")
    train!(strategy, init_val, model, inflow_model, feas_spaces, parameters; optimizer=optimizer, datapath = resultpath)
    using Serialization
    serialize(joinpath(@__DIR__, case*label*"strategy.jls"), strategy) # Save cuts to file
    println("Strategy saved to ", joinpath(@__DIR__, case*label*"strategy.jls"))
    strategy = deserialize(joinpath(@__DIR__, case*label*"strategy.jls")) # Load cuts from file

    if (save_strategy_to_file)
        # Save strategy to file
        file = File(format"JLD2", joinpath(@__DIR__, case*label*"strategy.jld2"))
        save(file, "strategy", strategy)

        # Load strategy from file
        data = JLD2.load(file) 
        strategy = data["strategy"]
    end
end

# Simulate aggregated
println("Start simulation ..")
results_agg = simulate_aggregated(model, inflow_model, parameters, strategy, feas_spaces, init_val, optimizer=optimizer)

# Print results to ASCII files 
println("Writing results to "*resultpath)
print_results(resultpath,results_agg,model.NArea,model.NHSys,parameters.Control.NScenSim,parameters.Control.NStageSim,parameters.Time.NK,model.NLine,parameters.Time)
print_dims(resultpath,model.NHSys,parameters.Control.NStage,parameters.Control.NScenSim,strategy.NCut,parameters.Control.MaxIter,parameters.Control.CCMaxIter)
print_strategy(resultpath,strategy,parameters.Control.LCostApprox)
print_feas(resultpath,feas_spaces[1],model.NHSys)
print_results_h5(resultpath,results_agg,model.NArea,model.NHSys,parameters.Control.NScenSim,parameters.Control.NStageSim,parameters.Time.NK,model.NLine,parameters.Time, model.MCon, model.AreaName)

open(joinpath(resultpath,"NScen.txt"), "w") do file
    write(file, string(NScen))
end

if (detailed_sim)
    println("Start detailed simulation ..")
    results_det = simulate_detailed(model, inflow_model, parameters, strategy, optimizer=optimizer)

    println("Write detailed results ..")
    print_detailed_results(resultpath,results_det,model.NArea,model.NHSys,parameters.Control.NScenSim,parameters.Control.NStageSim,parameters.Time.NK,model.NLine,parameters.Time,model.AHData)
    print_detailed_results_h5(resultpath,results_det,model.NArea,model.NHSys,parameters.Control.NScenSim,parameters.Control.NStageSim,parameters.Time.NK,model.NLine,parameters.Time,model.AHData,model.MCon,model.AreaName)
    println("Program finished.")

end