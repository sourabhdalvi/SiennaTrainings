using PowerSystems
using PowerSimulations
using Dates
using Logging
using StorageSystemsSimulations

# Configure the logger with info level logging
logger = configure_logging(console_level=Logging.Info)

# Define constants for package namespaces
const PSI = PowerSimulations
const PSY = PowerSystems

using TimeSeries
using JuMP
using Xpress
using HiGHS

### Parsing Args
# Parse command line arguments for simulation name, system path, and output directory
sim_name = ARGS[1]
sys_path = ARGS[2]
output_dir = ARGS[3]

# Simulation setting
interval = 24
horizon = 48
steps = 1

# Example input Arguments
# Uncomment and set values manually or use command line arguments as above
# sim_name = "test"
# sys_path = "data/RTS_GMLC_DA.json"
# output_dir =  "./simulation_output"

### Simulation Setup

# Create the output directory if it doesn't exist
if !ispath(output_dir)
    mkpath(output_dir)
end

# Create an Xpress optimizer object with specified attributes
solver = optimizer_with_attributes(
    Xpress.Optimizer, 
    "MIPRELSTOP" => 1e-5,   # Set the relative MIP gap tolerance
    "OUTPUTLOG" => 1,       # Enable logging
    "MAXTIME" => 200,      # Set the maximum solver time (in seconds)
    # "THREADS" => 12,        # Set the number of solver threads to use
    "MAXMEMORYSOFT" => 90000 # Set the maximum amount of memory the solver can use (in MB)
)

# or using an Open-source solver
solver = optimizer_with_attributes(
    HiGHS.Optimizer,
    "time_limit" => 150.0,     # Set the maximum solver time (in seconds)
    "threads" => 12,           # Set the number of solver threads to use
    "log_to_console" => true,  # Enable logging
    "mip_abs_gap" => 1e-5      # Set the relative MIP gap tolerance
)


# Create a Power Systems model from the specified system path
sys = System(sys_path)

# Transforming Static Time Series into Forecasts
# In many modeling workflows, it's common to transform data generated from a
# realization and stored in a single column into deterministic forecasts.
# This transformation accounts for the effects of lookahead without duplicating
# data.
# transform_single_time_series!(sys, horizon, interval) where horizon is
# expected to be Int and Interval should be a time period.
PSY.transform_single_time_series!(sys, horizon, Hour(interval))

# PowerSimulations.jl Modeling Structure
# PowerSimulations enables the simulation of a sequence of power systems
# optimization problems and provides user control over each aspect of the
# simulation configuration. Specifically, it follows a structured approach
# consisting of the following components:
# 
# 1. Mathematical Formulations: Mathematical formulations can be selected for
#    each component using DeviceModel and ServiceModel.
# 
# 2. Problem Definition: A problem can be defined by creating model entries in
#    Operations ProblemTemplates.
# 
# 3. Model Building: Models, such as DecisionModel or EmulationModel, can be
#    built by applying a ProblemTemplate to a System and can be
#    executed/solved in isolation or as part of a Simulation.
# 
# 4. Simulation: Simulations can be defined and executed by sequencing one or
#    more models and defining how and when data flows between models.



# Create a Template for the Unit Commitment (UC) Problem
# This involves defining the problem template, starting with the selection
# of the NetworkModel for the simulation problem. The most common models
# include CopperPlatePowerModel, NFAPowerModel (a simple Transport model),
# DCPPowerModel, and StandardPTDFModel. The NetworkModel also allows the
# user to specify settings related to which duals/LMPs the model should select.
# This can be specific to the network representation chosen; for example, 
# DCPPowerModel and NFAPowerModel create NodalBalanceActiveConstraint, and 
# the duals for this constraint represent the LMPs. In cases where the problem
# might be infeasible (not enough supply to meet demand), users can use slack
# variables to allow for dropped load or excess generation, which incurs a 
# cost of $10,000/MWh.

template_uc = ProblemTemplate(NetworkModel(PSI.CopperPlatePowerModel, duals=[CopperPlateBalanceConstraint], use_slacks=true))

# The ProblemTemplate also consists of two other models that help users 
# describe the technical requirements for the simulations. The DeviceModel 
# specifies which component type you want to model and with which formulation. 
# Some models can also have custom options, such as getting duals and 
# turning on/off custom constraints.

# To find which combinations of Device Types and Device formulations are compatible, 
# I recommend trying `generate_formulation_combinations`. This function will return 
# a dictionary of feasible sets of Device Type-Formulation pairs for a given system.
combos = PSI.generate_formulation_combinations(sys)

# To write these combination to a file 
PSI.write_formulation_combinations("./simulation_templates/device_models.json", sys)

# To see the compatiable formulations for different thermal devices, look here in the docs [https://nrel-sienna.github.io/PowerSimulations.jl/latest/formulation_library/ThermalGen/]
set_device_model!(template_uc, ThermalStandard, ThermalStandardUnitCommitment)
set_device_model!(template_uc, ThermalMultiStart, ThermalBasicUnitCommitment)
set_device_model!(template_uc, GenericBattery, StorageDispatchWithReserves)
set_device_model!(template_uc, PowerLoad, StaticPowerLoad)
set_device_model!(template_uc, RenewableDispatch, RenewableFullDispatch)
set_device_model!(template_uc, MonitoredLine, StaticBranchBounds)
set_device_model!(template_uc, Line, StaticBranch)
set_device_model!(template_uc, Transformer2W, StaticBranch)
set_device_model!(template_uc, TapTransformer, StaticBranch)

# ServiceModels are very similar to the rest. They help select the type of reserve provision 
# to be modeled with options like getting duals and slack.
set_service_model!(
    template_uc,
    ServiceModel(
        VariableReserve{ReserveUp},
        RangeReserve,
        use_slacks=true,
    )
)

# Define the simulation models
models = SimulationModels(
    decision_models=[
        DecisionModel(
            template_uc,
            sys,
            name="UC",
            optimizer=solver,
            initialize_model=false,
            optimizer_solve_log_print=true,
            check_numerical_bounds=false,
            warm_start=true,
            store_variable_names=true,
        ),
    ],
)

# Define the simulation sequence
sequence =
    SimulationSequence(models=models, ini_cond_chronology=InterProblemChronology())

# Create a simulation object
sim = Simulation(
    name="$(sim_name)",
    steps=steps,
    models=models,
    sequence=sequence,
    simulation_folder=output_dir,
)

# Build the simulation
build!(sim, serialize=true)

# Execute the simulation with a progress bar
execute!(sim, enable_progress_bar=true)

# If you want to investigate the variables and constraints in the DecisionModel, 
# all the information can be found in the OptimizationContainer. 
# Note that for any type of debugging or inspection of the model, 
# make sure you have passed the kwarg `store_variable_names=true` in the Decision model.
model = get_simulation_model(sim, :UC)
optimization_cont = PSI.get_optimization_container(model)

# You can list all the variables that are included in the optimization model here. 
# The nomenclature of how variable keys are defined uses the variable name and device type. 
# Sometimes they may also have a meta string attached to differentiate, 
# e.g., VariableKey{ActivePowerReserveVariable, VariableReserve{ReserveUp}}("Spin_Up_R3") 
# and VariableKey{ActivePowerReserveVariable, VariableReserve{ReserveUp}}("Spin_Up_R1").
variables_dict = PSI.get_variables(optimization_cont)
keys(variables_dict)

# You can also inspect the variable array which is index by device name and time steps
variables_dict[PSI.VariableKey{PSI.ActivePowerVariable, PSY.ThermalStandard}("")]

# Similarly for inspecting constraint in a model
constraints_dict = PSI.get_constraints(optimization_cont)
keys(constraints_dict)

# You can also inspect the constraint array which is index by device name and time steps
constraints_dict[PSI.ConstraintKey{PSI.RampConstraint, PSY.ThermalStandard}("up")]["202_STEAM_3", 1]

# Finally, if you would like to examine the entire model, you can save the JuMP Model to a text file using the code below.
# I highly recommend reducing the number of time periods, or this file can become very large quite quickly.
open("model.txt", "w") do f
    println(f, PSI.get_jump_model(optimization_cont))
end