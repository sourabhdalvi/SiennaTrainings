using PowerSystems
using PowerSimulations
using Dates
using Logging
logger = configure_logging(console_level=Logging.Info)
const PSI = PowerSimulations
const PSY = PowerSystems
using TimeSeries
using JuMP
using Xpress
using HiGHS
using StorageSystemsSimulations

### Parsing Args
sim_name = ARGS[1]
sys_name = ARGS[2]
output_dir =  ARGS[3]
#=
sim_name = "test"
sys_name = "data/RTS_GMLC_DA_test_modifications.json"
output_dir =  "./simulation_output"
=#
interval = 24
horizon = 48
steps = 2

### Simulation Setup

if !ispath(output_dir)
    mkpath(output_dir)
end

# using an Open-source solver HiGHs to create optimizer object with specified attributes 
solver = optimizer_with_attributes(
    HiGHS.Optimizer,
    "time_limit" => 150.0,     # Set the maximum solver time (in seconds)
    "threads" => 12,           # Set the number of solver threads to use
    "log_to_console" => true,  # Enable logging
    "mip_abs_gap" => 1e-5      # Set the relative MIP gap tolerance
)

template_uc = PSI.template_unit_commitment(; network = CopperPlatePowerModel)

sys = System(sys_path; time_series_directory="/tmp/scratch")
PSY.transform_single_time_series!(sys, horizon, Hour(interval))

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

sequence =
    SimulationSequence(models=models, ini_cond_chronology=InterProblemChronology())

sim = Simulation(
    name="$(sim_name)",
    steps=steps,
    models=models,
    sequence=sequence,
    simulation_folder=output_dir,
)
build!(sim, serialize=true)
execute!(sim, enable_progress_bar=true)

