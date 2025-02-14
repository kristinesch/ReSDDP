
import Pkg
import Revise

using Revise # Sikrer at oppdateringer av kildekode kompileres automatisk
using Pkg
Pkg.activate(@__DIR__) # Aktiverer lokalt pakkemiljø
# Pkg.resolve()
Pkg.instantiate()

using ReSDDP
include("params.jl") # Import parameters

import JuMP
import YAML
import CPLEX
optimizer = JuMP.optimizer_with_attributes(
    CPLEX.Optimizer,
    #"CPX_PARAM_THREADS" => 2,
    "CPX_PARAM_SCRIND" => 0,
    "CPX_PARAM_PREIND" => 1,
    "CPX_PARAM_LPMETHOD" => 2 #1=primal, 2=dual, 3=network, 4=barrier
)

println("Threads available: ",Threads.nthreads())

#case = "4area"
cases = ["4area","expanded_dem-h2pris45_headcorr_fansi-batt_increase50p"]

#for selecting which case to run
println("Select case: ")
for (i, c) in enumerate(cases)
    println(string(i)*": "*c)
end
case_i = readline()
case = cases[parse(Int64,case_i)]

#Enter optional extra label
label = ""
println("Enter label: ")
label = readline()

#read config file
config = YAML.load_file("config.yaml")

#turn on or off different steps
calculate_feasibility_cuts = true #set to false if already done, needs to be true for first run
detailed_sim = true
save_strategy_to_file = true
if (config["calculate_feasibility_cuts"] == "false")
    calculate_feasibility_cuts = false
end
if (config["detailed_sim"] == "false")
    detailed_sim = false
end
if (config["save_strategy_to_file"] == "false")
    save_strategy_to_file = false
end

if (LFeasCut == true)
    if (LFeasPerStage == false)
        label = label*"-feas1"
    end
    else
        label = label*"-feasN"
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

#load data
model = load(datapath, parameters) 
inflow_model = load_inflow(datapath, model, parameters)

using JLD2 
using FileIO 

 # Save feasibility cuts to file
file = File(format"JLD2", joinpath(@__DIR__, "feas_spaces.jld2"))


if (calculate_feasibility_cuts)
    #Compute feasibility cuts 
    println("Compute feasibility cuts..")
    feas_spaces = feasibility(model, inflow_model, parameters, datapath; optimizer=optimizer)
    save(file, "feas_spaces", feas_spaces)
   
end

# Load feasibility cuts from file
data = JLD2.load(file) 
feas_spaces = data["feas_spaces"]

ReSDDP.print(model, parameters, true, true)

strategy = init_strategy(model, parameters)
init_val = init_system(model, parameters)

#Compute strategy by SDDP
println("Start strategy computation..")

train!(strategy, init_val, model, inflow_model, feas_spaces, parameters; optimizer=optimizer)
using Serialization
serialize(joinpath(@__DIR__, "strategy.jls"), strategy) # Save cuts to file
strategy = deserialize(joinpath(@__DIR__, "strategy.jls")) # Load cuts from file

if (save_strategy_to_file)
    # Save strategy to file
    file = File(format"JLD2", joinpath(@__DIR__, "strategy.jld2"))
    save(file, "strategy", strategy)

    # Load strategy from file
    data = JLD2.load(file) 
    strategy = data["strategy"]
end

# Simulate aggregated
println("Start simulation ..")
results_agg = simulate_aggregated(model, inflow_model, parameters, strategy, feas_spaces, init_val)

# Print results to ASCII files 
println("Write results ..")
print_results(resultpath,results_agg,model.NArea,model.NHSys,parameters.Control.NScenSim,parameters.Control.NStageSim,parameters.Time.NK,model.NLine,parameters.Time)
print_dims(resultpath,model.NHSys,parameters.Control.NStage,parameters.Control.NScenSim,strategy.NCut,parameters.Control.MaxIter,parameters.Control.CCMaxIter)
print_strategy(resultpath,strategy,parameters.Control.LCostApprox)
print_feas(resultpath,feas_spaces[1],model.NHSys)

if (detailed_sim)
    println("Start detailed simulation ..")
    results_det = simulate_detailed(model, inflow_model, parameters, strategy)

    println("Write detailed results ..")
    print_detailed_results(resultpath,results_det,model.NArea,model.NHSys,parameters.Control.NScenSim,parameters.Control.NStageSim,parameters.Time.NK,model.NLine,parameters.Time,model.AHData)
end