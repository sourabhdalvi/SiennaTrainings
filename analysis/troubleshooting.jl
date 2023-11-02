using PowerSimulations
using PowerSystems
const PSI = PowerSimulations
const PSY = PowerSystems
using DataFrames
using TimeSeries
using CSV
using Dates
using SIIP2Marmot

### 1. First Example how to resolve a infeasiblity in Sienna

sys = PSY.System(
    "../data/WECC_ADS_2030_PCM.json",
    runchecks=false,
    time_series_read_only=true,
    time_series_directory="/tmp/scratch",
);
transform_single_time_series!(sys, 24, Hour(24))

# Define the output directory for the simulation results
output_dir = joinpath(dirname(pwd()), "simulation_results")

# Check if the output directory exists, and create it if it doesn't
if !ispath(output_dir)
    mkpath(output_dir)
end

# Create an Xpress optimizer object with specified attributes
solver = optimizer_with_attributes(
    Xpress.Optimizer,
    "MIPRELSTOP" => 1e-5, # Set the relative mip gap tolerance
    "OUTPUTLOG" => 1, # Enable logging
    "MAXTIME" => 1000, # Set the maximum solver time (in seconds)
    "THREADS" => 12, # Set the number of solver threads to use
    "MAXMEMORYSOFT" => 30000, # Set the maximum amount of memory the solver can use (in MB)
)
# Create a unit commitment template using the PSI package, with the CopperPlatePowerModel network as input
template_uc = PSI.template_unit_commitment(; network=CopperPlatePowerModel)

# Load the system data from the specified directory and set up the time series data
sys = System(sys_path; time_series_directory="/tmp/scratch")
PSY.transform_single_time_series!(sys, horizon, Hour(interval))

# Create a SimulationModels object with a single DecisionModel
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
            store_variable_names=true, # For debugging make sure these 
            calculate_conflict=true, # two options are enabled
        ),
    ],
)

# Create a SimulationSequence object with the SimulationModels object and an InterProblemChronology object
sequence = SimulationSequence(models=models, ini_cond_chronology=InterProblemChronology())

# Create a Simulation object with a specified name, number of steps, and the SimulationSequence object
sim = Simulation(
    name="$(sim_name)",
    steps=steps,
    models=models,
    sequence=sequence,
    simulation_folder=output_dir,
)

# Build the simulation and serialize it
build!(sim, serialize=true)

# Execute the simulation with a progress bar enabled
execute!(sim, enable_progress_bar=true)

### 2. Vetting PVe or Wind Time series data

pv = first(get_components(x -> x.prime_mover == PSY.PrimeMovers.PVe, RenewableGen, sys))
ts = get_time_series_array(
    SingleTimeSeries,
    pv,
    "max_active_power";
    ignore_scaling_factors=false,
    len=24,
)
plot(ts)

wind = first(get_components(x -> x.prime_mover == PSY.PrimeMovers.WT, RenewableGen, sys))
ts = get_time_series_array(
    SingleTimeSeries,
    wind,
    "max_active_power";
    ignore_scaling_factors=true,
    len=24,
)
plot(ts)
# or using PowerSystemsApps to create a table of system data

### 3. 
