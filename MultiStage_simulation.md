
## Package Imports

```julia
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
```

### Parsing Command Line Arguments

```julia
# Parse command line arguments for simulation name, system path for Day-ahead and Real-time systems, and output directory
sim_name = ARGS[1]
sys_path_DA = ARGS[2]
sys_path_RT = ARGS[2]
output_dir = ARGS[3]

# Simulation settings
interval = 24          # Hourly time interval
horizon = 48           # 2-day horizon for Day-ahead
interval_RT = 15       # 15-min resolution
horizon_RT = 12        # 1-hour horizon for Real-time (12 steps at 5-min res)
steps = 1              # Number of simulation days
```

### Simulation Setup

```julia
# Create the output directory if it doesn't exist
if !ispath(output_dir)
    mkpath(output_dir)
end
```

### Solver Configuration
Create an Xpress optimizer object with specified attributes
```julia
#
solver = optimizer_with_attributes(
    Xpress.Optimizer, 
    "MIPRELSTOP" => 1e-5,   # Set the relative mip gap tolerance
    "OUTPUTLOG" => 1,       # Enable logging
    "MAXTIME" => 300,       # Set the maximum solver time (in seconds)
    "THREADS" => 12,        # Set the number of solver threads to use
    "MAXMEMORYSOFT" => 30000 # Set the maximum amount of memory the solver can use (in MB)
)
```
Alternatively, use an open-source solver HiGHS
```julia
solver = optimizer_with_attributes(
    HiGHS.Optimizer,
    "time_limit" => 150.0,     # Set the maximum solver time (in seconds)
    "threads" => 12,           # Set the number of solver threads to use
    "log_to_console" => true,  # Enable logging
    "mip_abs_gap" => 1e-5      # Set the relative MIP gap tolerance
)
```

### Creating Power Systems Models

```julia
# Create a PowerSystems System from the specified system paths
sys_DA = System(sys_path_DA)
sys_RT = System(sys_path_RT)

# Transforming Static Time Series into Forecasts
PSY.transform_single_time_series!(sys_DA, horizon, Hour(interval))
PSY.transform_single_time_series!(sys_RT, horizon_RT, Minute(interval_RT))
```

### PowerSimulations.jl Modeling Structure

PowerSimulations.jl enables the simulation of power systems optimization problems in a structured approach. It consists of the following components:

1. **Mathematical Formulations**: Mathematical formulations can be selected for each component using `DeviceModel` and `ServiceModel`.

2. **Problem Definition**: A problem can be defined by creating model entries in Operations ProblemTemplates.

3. **Model Building**: Models, such as `DecisionModel` or `EmulationModel`, can be built by applying a `ProblemTemplate` to a `System` and can be executed/solved in isolation or as part of a `Simulation`.

4. **Simulation**: Simulations can be defined and executed by sequencing one or more models and defining how and when data flows between models.

### Creating a Template for the Unit Commitment (UC) Problem

```julia
template_uc = ProblemTemplate(NetworkModel(PSI.CopperPlatePowerModel, duals=[CopperPlateBalanceConstraint], use_slacks=true))
set_device_model!(template_uc, ThermalStandard, ThermalStandardUnitCommitment)
set_device_model!(template_uc, ThermalMultiStart, ThermalBasicUnitCommitment)
set_device_model!(template_uc, GenericBattery, SS.StorageDispatch)
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
```

### Defining the Simulation Models

```julia
# Define the simulation models in the sequence of execution 
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
```
## Defining the Simulation Sequence

The `SimulationSequence` is primarily relevant for multi-stage models. It serves as the mechanism to orchestrate the flow of information between Decision models. In this example, we're dealing with a classic Unit Commitment (UC) to Economic Dispatch (ED) simulation, where the goal is to convey the commitment status from the UC problem to the ED problem. To achieve this, Sienna offers the `SemiContinuousFeedforward` object, which enables us to forward the commitment status of the thermal generator using a constraint within the Economic Dispatch model.

### Available FeedForwards

#### EnergyLimitFeedforward
Adds a constraint to limit the sum of a variable over the number of periods to the source value.

```julia
EnergyLimitFeedforward(;
    component_type = GenericBattery,
    source = EnergyVariable,
    affected_values = [EnergyVariable],
    number_of_periods = 10,
)
```

#### EnergyTargetFeedforward
Adds a constraint to enforce a minimum energy level target with a slack variable associated with a penalty term.

```julia
EnergyTargetFeedforward(;
    component_type = GenericBattery,
    source = EnergyVariable,
    affected_values = [EnergyVariable],
    target_period = 24,
    penalty_cost = 10000,
)
```

#### SemiContinuousFeedforward
Adds a constraint to make the bounds of a variable 0.0. Effectively allows turning off a value.

```julia
SemiContinuousFeedforward(;
    component_type = ThermalMultiStart,
    source = OnVariable,
    affected_values = [ActivePowerVariable, ReactivePowerVariable],
)
```

#### LowerBoundFeedforward
Adds a lower bound constraint to a variable.

```julia
LowerBoundFeedforward(;
    component_type = RenewableDispatch,
    source = ActivePowerVariable,
    affected_values = [ActivePowerVariable],
)
```

#### UpperBoundFeedforward
Adds an upper bound constraint to a variable.

```julia
UpperBoundFeedforward(;
    component_type = RenewableDispatch,
    source = ActivePowerVariable,
    affected_values = [ActivePowerVariable],
)
```

#### FixValueFeedforward
Fixes a Variable or Parameter Value in the model. Is the only Feed Forward that can be used with a Parameter or a Variable as the affected value.

```julia
ff = FixValueFeedforward(;
    component_type = HydroDispatch,
    source = OnVariable,
    affected_values = [OnStatusParameter],
)
```

Now we proceed to building the SimulationSequence for this example simulation.

```julia
# Define the simulation sequence
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
```
In this snippet, we create a SimulationSequence object that specifies how different models interact with each other. Specifically, it defines the transfer of information from the Unit Commitment (UC) model to the Economic Dispatch (ED) model using the SemiContinuousFeedforward mechanism.

### Creating a Simulation Object
Once you've defined the necessary components, such as stages, models, and the simulation sequence, you can proceed to create and execute a simulation in PowerSimulations. 

```julia
# Create a simulation object
sim = Simulation(
    name="$(sim_name)",
    steps=steps,
    models=models,
    sequence=sequence,
    simulation_folder=output_dir,
    initial_time=DateTime("2024-01-01T00:00:00"),
)

# Build the simulation
build!(sim)

# Execute the simulation with a progress bar
execute!(sim, enable_progress_bar=true)
```
