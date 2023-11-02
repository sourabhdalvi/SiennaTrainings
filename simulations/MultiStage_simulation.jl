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
using StorageSystemsSimulations
using HiGHS

### Parsing Args
sim_name = ARGS[1]
sys_path_DA = ARGS[2]
sys_path_RT = ARGS[2]
output_dir = ARGS[3]

# Simulation setting
interval = 24          # Hourly time interval
horizon = 48           # 2-day horizon for Day-ahead
interval_RT = 15       # 15-min resolution
horizon_RT = 12        # 1-hour horizon for Real-time (12 steps at 5-min res)
steps = 1              # Number of simulation days

if !ispath(output_dir)
    mkpath(output_dir)
end

# Create an Xpress optimizer object with specified attributes
solver = optimizer_with_attributes(
    Xpress.Optimizer,
    "MIPRELSTOP" => 1e-5, # Set the relative mip gap tolerance
    "OUTPUTLOG" => 1, # Enable logging
    "MAXTIME" => 300, # Set the maximum solver time (in seconds)
)

sys_DA = System(sys_path_DA)
sys_RT = System(sys_path_RT)
PSY.transform_single_time_series!(sys_DA, horizon, Hour(interval))
PSY.transform_single_time_series!(sys_RT, horizon_RT, Minute(interval_RT))

template_uc =
    PSI.template_unit_commitment(; network=NetworkModel(StandardPTDFModel, use_slacks=true))
template_rt = PSI.template_economic_dispatch(;
    network=NetworkModel(StandardPTDFModel, use_slacks=true),
)

models = SimulationModels(
    decision_models=[
        DecisionModel(
            template_uc,
            sys_DA,
            name="UC",
            optimizer=solver,
            initialize_model=false,
            optimizer_solve_log_print=true,
            direct_mode_optimizer=true,
            check_numerical_bounds=false,
            warm_start=true,
        ),
        DecisionModel(
            template_rt,
            sys_RT,
            name="RT",
            optimizer=solver,
            initialize_model=false,
            optimizer_solve_log_print=true,
            direct_mode_optimizer=true,
            check_numerical_bounds=false,
            warm_start=true,
        ),
    ],
)

sequence = SimulationSequence(
    models=models,
    feedforwards=Dict(
        "RT" => [
            SemiContinuousFeedforward(;
                component_type=ThermalStandard,
                source=OnVariable,
                affected_values=[ActivePowerVariable],
            ),
            SemiContinuousFeedforward(;
                component_type=ThermalMultiStart,
                source=OnVariable,
                affected_values=[ActivePowerVariable],
            ),
        ],
    ),
    ini_cond_chronology=InterProblemChronology(),
)

sim = Simulation(
    name="$(sim_name)",
    steps=steps,
    models=models,
    sequence=sequence,
    simulation_folder=output_dir,
)

build!(sim)
execute!(sim, enable_progress_bar=true)
