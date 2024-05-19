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
# Parse command line arguments for simulation name, system path for Day-ahead and Real-time systems, and output directory
sim_name = ARGS[1]
sys_path_DA = ARGS[2]
sys_path_RT = ARGS[2]
output_dir =  ARGS[3]

# Simulation setting
interval = 24          # Hourly time interval
horizon = 48           # 2-day horizon for Day-ahead
interval_RT = 15       # 15-min resolution
horizon_RT = 12        # 1-hour horizon for Real-time (12 steps at 5-min res)
steps = 1              # Number of simulation days

### Simulation Setup

# Create the output directory if it doesn't exist
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

# Create a PowerSystems System from the specified system path
# Please keep in mind if you are running on eagle/kestrel to add kwarg for
# time series directory `time_series_directory="/tmp/scratch"`

sys_DA = System(sys_path_DA)
sys_RT = System(sys_path_RT)

# Transforming Static Time Series into Forecasts
# In many modeling workflows, it's common to transform data generated from a
# realization and stored in a single column into deterministic forecasts.
# This transformation accounts for the effects of lookahead without duplicating
# data.
# transform_single_time_series!(sys, horizon, interval) where horizon is
# expected to be Int and Interval should be a time period.
PSY.transform_single_time_series!(sys_DA, horizon, Hour(interval))
PSY.transform_single_time_series!(sys_RT, horizon_RT, Minute(interval_RT))

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

# Create a template for the Unit Commitment (UC) problem
template_uc = ProblemTemplate(NetworkModel(PSI.CopperPlatePowerModel, duals=[CopperPlateBalanceConstraint], use_slacks=true))
set_device_model!(template_uc, ThermalStandard, ThermalStandardUnitCommitment)
set_device_model!(template_uc, ThermalMultiStart, ThermalBasicUnitCommitment)
set_device_model!(template_uc, GenericBattery, StorageDispatchWithReserves)
set_device_model!(template_uc, PowerLoad, StaticPowerLoad)
set_device_model!(template_uc, RenewableDispatch, RenewableFullDispatch)
set_device_model!(template_uc, MonitoredLine, StaticBranchBounds)
set_device_model!(template_uc, Line, StaticBranch)
set_device_model!(template_uc, Transformer2W, StaticBranch)
set_device_model!(template_uc, TapTransformer, StaticBranch)
set_service_model!(
    template_uc,
    ServiceModel(
        VariableReserve{ReserveUp},
        RangeReserve,
        use_slacks=true,
    )
)

# Create a template for the Economic Dispatch (ED) problem
template_rt = ProblemTemplate(NetworkModel(PSI.CopperPlatePowerModel, duals=[CopperPlateBalanceConstraint], use_slacks=true))
set_device_model!(template_rt, ThermalStandard, ThermalStandardDispatch)
set_device_model!(template_rt, ThermalMultiStart, ThermalBasicDispatch)
set_device_model!(template_rt, GenericBattery, StorageDispatchWithReserves)
set_device_model!(template_rt, PowerLoad, StaticPowerLoad)
set_device_model!(template_rt, RenewableDispatch, RenewableFullDispatch)
set_device_model!(template_rt, MonitoredLine, StaticBranchBounds)
set_device_model!(template_rt, Line, StaticBranch)
set_device_model!(template_rt, Transformer2W, StaticBranch)
set_device_model!(template_rt, TapTransformer, StaticBranch)

# Define the simulation models in the sequence of excution 
models = SimulationModels(
    decision_models=[
        DecisionModel(template_uc,
            sys_DA,
            name="UC",
            optimizer=solver,
            initialize_model=false,
            optimizer_solve_log_print=true,
            direct_mode_optimizer=true,
            check_numerical_bounds=false,
            warm_start=true,
        ),
        DecisionModel(template_rt,
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


## Define the simulation sequence
# The SimulationSequence is primarily relevant for multi-stage models.
# It's the mechanism Sienna employs to understand what information needs
# to be transferred between the Decision models. In this example, we're
# dealing with a classic UC-ED simulation, where we aim to convey the
# commitment status from the UC problem to the ED problem. To achieve this,
# Sienna offers the SemiContinuousFeedforward object, which enables us to
# forward the commitment status of the thermal generator using a constraint
# within the Economic Dispatch model.

sequence = SimulationSequence(
    models=models,
    feedforwards=Dict(
        "RT" => [
            SemiContinuousFeedforward(;
                component_type = ThermalStandard,
                source = OnVariable,
                affected_values = [ActivePowerVariable],
            ),
            SemiContinuousFeedforward(;
                component_type = ThermalMultiStart,
                source = OnVariable,
                affected_values = [ActivePowerVariable],
            ),
        ],
    ),
    ini_cond_chronology=InterProblemChronology(),
)

# Create a simulation object
sim = Simulation(
    name="$(sim_name)",
    steps=steps,
    models=models,
    sequence=sequence,
    simulation_folder=output_dir,
    # initial_time=DateTime("2024-01-01T00:00:00"),
)

# Create a simulation object
build!(sim,)

# Execute the simulation with a progress bar
execute!(sim, enable_progress_bar=true,)
