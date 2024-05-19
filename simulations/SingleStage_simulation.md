## Package Imports

```julia
using PowerSystems
using PowerSimulations
using Dates
using Logging
using StorageSystemsSimulations
```

### Logging Configuration

```julia
# Configure the logger with info level logging
logger = configure_logging(console_level=Logging.Info)
```

### Package Constants

```julia
# Define constants for package namespaces
const PSI = PowerSimulations
const PSY = PowerSystems
```

## Parsing Command Line Arguments

```julia
# Parse command line arguments for simulation name, system path, and output directory
sim_name = ARGS[1]
sys_path = ARGS[2]
output_dir = ARGS[3]
```

## Simulation Settings

```julia
# Example input Arguments
# Uncomment and set values manually or use command line arguments as above
# sim_name = "test"
# sys_path = "data/RTS_GMLC_DA.json"
# output_dir =  "./simulation_output"

# Simulation setting
interval = 24
horizon = 48
steps = 1
```

## Simulation Setup

```julia
# Create the output directory if it doesn't exist
if !ispath(output_dir)
    mkpath(output_dir)
end
```

## Solver Configuration

```julia
# using an Open-source solver HiGHs to create optimizer object with specified attributes 
solver = optimizer_with_attributes(
    HiGHS.Optimizer,
    "time_limit" => 150.0,     # Set the maximum solver time (in seconds)
    "threads" => 12,           # Set the number of solver threads to use
    "log_to_console" => true,  # Enable logging
    "mip_abs_gap" => 1e-5      # Set the relative MIP gap tolerance
)
```

## Creating a Power Systems Model

```julia
# Create a Power Systems model from the specified system path
sys = System(sys_path)
PSY.transform_single_time_series!(sys, horizon, Hour(interval))
```

## PowerSimulations.jl Modeling Structure

PowerSimulations.jl follows a structured approach for modeling power systems. The following components are part of this structure:

1. **Mathematical Formulations:** Mathematical formulations can be selected for each component using `DeviceModel` and `ServiceModel`.

2. **Problem Definition:** A problem can be defined by creating model entries in an Operations ProblemTemplates.

3. **Model Building:** Models, such as `DecisionModel` or `EmulationModel`, can be built by applying a `ProblemTemplate` to a `System` and can be executed/solved in isolation or as part of a `Simulation`.

4. **Simulation:** Simulations can be defined and executed by sequencing one or more models and defining how and when data flows between models.


## Creating a Template for the Unit Commitment (UC) Problem

To set up the Unit Commitment (UC) problem, we create a problem template. This involves defining various parameters and settings:

- **Network Model Selection**: Start by selecting the appropriate `NetworkModel` for the simulation problem. Common models include:
    - `CopperPlatePowerModel`
    - `NFAPowerModel`
    - `DCPPowerModel`
    - `StandardPTDFModel`

  The choice of `NetworkModel` also allows you to specify settings related to which duals/LMPs the model should retrieve. This can vary depending on the network representation chosen. For example, `DCPPowerModel` and `NFAPowerModel` create a `NodalBalanceActiveConstraint`, and the duals for this constraint represent the Locational Marginal Prices (LMPs).

- **Handling Infeasible Scenarios**: In cases where the problem might be infeasible (i.e., not enough supply to meet demand), you have the option to use slack variables (`use_slacks=true`). These slack variables allow for dropped load or excess generation and incur a cost of $10,000/MWh.

Here's an example of creating the `template_uc` for the UC problem:

```julia
template_uc = ProblemTemplate(NetworkModel(PSI.CopperPlatePowerModel, duals=[CopperPlateBalanceConstraint], use_slacks=true))
```

### Understanding Problem Templates and Device Models

In addition to the `NetworkModel` selection, the `ProblemTemplate` also comprises two other crucial components for defining simulation problems `DeviceModel` and `ServiceModel`:

- **Device Model**: The `DeviceModel` specifies the type of components you want to model and with which formulation. This choice can greatly affect the technical aspects of your simulation.

    - Most device models provide interface to access options dual values for constratints, slack to relax constraints and toggling custom constraints using `attributes`. These options allow you to fine-tune your simulation to your specific requirements.

### Exploring Compatible Formulations for Devices

To explore the compatible formulations available for various types of devices in PowerSimulations.jl, you can refer to the official documentation. Here are the relevant links to access detailed information on device formulations:

- **Thermal Devices:** Visit [PowerSimulations Thermal Device Formulations](https://nrel-sienna.github.io/PowerSimulations.jl/latest/formulation_library/ThermalGen/) for compatible formulations related to thermal devices.

- **Renewable Devices:** Explore [PowerSimulations Renewable Device Formulations](https://nrel-sienna.github.io/PowerSimulations.jl/latest/formulation_library/RenewableGen/) to find compatible formulations for renewable devices.

- **Load Devices:** For information on compatible formulations related to load devices, refer to [PowerSimulations Load Device Formulations](https://nrel-sienna.github.io/PowerSimulations.jl/latest/formulation_library/Load/).

These resources provide valuable insights into the available options for modeling different types of devices in your power system simulations. They can help you make informed decisions when selecting the appropriate device formulations for your specific simulation scenarios.


```julia

set_device_model!(template_uc, ThermalStandard, ThermalStandardUnitCommitment)
set_device_model!(template_uc, ThermalMultiStart, ThermalBasicUnitCommitment)
set_device_model!(template_uc, GenericBattery, StorageDispatchWithReserves)
set_device_model!(template_uc, PowerLoad, StaticPowerLoad)
set_device_model!(template_uc, RenewableDispatch, RenewableFullDispatch)
set_device_model!(template_uc, MonitoredLine, StaticBranchBounds)
set_device_model!(template_uc, Line, StaticBranch)
set_device_model!(template_uc, Transformer2W, StaticBranch)
set_device_model!(template_uc, TapTransformer, StaticBranch)
```
## Exploring Service Models

ServiceModels in PowerSimulations assist in selecting the type of reserve provision to be modeled. They offer various options, such as obtaining dual values and handling slack variables. ServiceModels play a crucial role in defining reserve and ancillary service provisions in power system simulations.


When working with ServiceModels, you can specify formulations for how reserve or ancillary services should be modeled. Below are a few example reserve formulations:

### RangeReserve

- **Description**: Only available headroom in generators is contributed towards reserve provision.
- **Use Case**: Useful when you want to consider only the unused capacity in generators for reserve provision.

### RampReserve

- **Description**: Available headroom + the generator's ability to ramp within the defined response is contributed towards reserve provision.
- **Use Case**: Suitable for scenarios where you need to account for both available capacity and the ability to respond quickly.

### StepwiseCostReserve

- **Description**: No reserve requirement is defined for each time period, but there is a stepwise cost curve associated with the amount of reserves provided. This implementation is similar to the Operating Reserve Demand Curve (ORDC) in ERCOT.
- **Use Case**: Ideal for modeling reserve provisions with varying costs over different time periods.

### NonSpinningReserve

- **Description**: Capture the generation capacity that didn't clear in the Day-ahead market but is able to quickly start up for contingency reserve provision.
- **Use Case**: Ideal for modeling non-spinning reserve for cases where Day-ahead and real-time operation are vastly different, either due to large forecast errors or outages.

### ConstantMaxInterfaceFlow 
- **Description**: which will be covered in more advanced examples

These models provide flexibility in customizing the behavior of reserve provision, allowing you to tailor them to your specific simulation requirements.


```julia
set_service_model!(
    template_uc,
    ServiceModel(
        VariableReserve{ReserveUp},
        RangeReserve,
        use_slacks=true,
    )
)
```

## Exploring Compatible Device Type and Formulation Combinations

To discover which combinations of Device Types and Device Formulations are compatible for your specific power system, you can use the `generate_formulation_combinations` function provided by PowerSimulations. This function will return a dictionary containing feasible sets of Device Type-Formulation pairs tailored to your system.

You can then save these combinations to a file for further reference:
```julia

combos = PSI.generate_formulation_combinations(sys)

# To write these combination to a file 
PSI.write_formulation_combinations("./simulation_templates/device_models.json", sys)
```

## Defining Simulation Models
The construction of an DecisionModel essentially applies an ProblemTemplate to System data to create a JuMP model and SimulationModels is just the collection of DecisionModels in one simulation.
```julia
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
```

## Defining the Simulation Sequence

In PowerSimulations, the simulation sequence is a crucial concept that dictates how information flows between different stages and executions within a simulation. The flow of information is essential for ensuring the accuracy and effectiveness of the simulation process. PowerSimulations defines two types of chronologies to manage this flow:

### Inter-Stage Chronologies

Inter-stage chronologies are responsible for defining how information flows between different stages of the simulation. For example, in a power system simulation, day-ahead solutions may be used to inform economic dispatch problems that occur in subsequent stages. This ensures that the results from one stage are appropriately utilized in the next.

### Intra-Stage Chronologies

Intra-stage chronologies, on the other hand, define how information flows within a single stage but across multiple executions of that stage. For instance, in an economic dispatch problem, the dispatch setpoints of the first time period may be constrained by the ramping limits based on setpoints from the final period of the previous execution of the same stage. 

Here's an example of how the simulation sequence is defined in Julia using PowerSimulations:

```julia
# Define the simulation sequence
sequence =
    SimulationSequence(models=models, ini_cond_chronology=InterProblemChronology())
```
In this example, the SimulationSequence is created, specifying the sequence of models to be executed and the use of the InterProblemChronology for managing information flow between stages. 

## Creating a Simulation

Once you've defined the necessary components, such as stages, models, and the simulation sequence, you can proceed to create and execute a simulation in PowerSimulations. 

```julia
sim = Simulation(
    name="$(sim_name)",
    steps=steps,
    models=models,
    sequence=sequence,
    simulation_folder=output_dir,
)
```
In this code snippet, a new simulation is created using the Simulation constructor. Let's break down the parameters:

- **name**: This parameter specifies the name of the simulation, which can be customized using the sim_name variable.
- **steps**: Here, you can define the number of simulation steps or iterations to execute.
models: This is where you specify the simulation models that you want to include in the simulation.
- **sequence**: You provide the defined simulation sequence, which controls the order and flow of operations.
- **simulation_folder**: Finally, you specify the folder where simulation-related files and results will be stored, and this is determined by the output_dir variable.

Once you've created the simulation object, you can proceed to build and execute the simulation, as shown in the subsequent sections. 
## Building the Simulation

```julia
# Build the simulation
build!(sim, serialize=true)
```

## Executing the Simulation

```julia
# Execute the simulation with a progress bar
execute!(sim, enable_progress_bar=true)
```

## Investigating Variables and Constraints

After running a simulation using PowerSimulations, you may want to examine the variables and constraints within a specific model. This section guides you through the process of investigating these components and provides insights into how to understand the simulation results.

### Accessing OptimizationContainer

Before diving into the details of variables and constraints, you need to access the `OptimizationContainer` that stores all the relevant information. To do this, follow these steps:

```julia
# Retrieve the DecisionModel from the simulation
model = get_simulation_model(sim, :UC)

# Access the OptimizationContainer
optimization_cont = PSI.get_optimization_container(model)

```
Please note that for effective debugging and inspection of the model, ensure that you have set the store_variable_names=true keyword argument when defining the Decision model. This will help maintain variable names and improve the clarity of your investigation.

###  Exploring Variables
Variables represent the quantities optimized by the simulation. They play a crucial role in modeling and solving power system optimization problems. Here's how you can explore the variables within your simulation:

```julia
# Get a dictionary of all variables in the optimization model
variables_dict = PSI.get_variables(optimization_cont)

# List all the variables included in the optimization model
keys(variables_dict)
```

The nomenclature used to define variable keys incorporates both the variable name and the device type. Sometimes, additional metadata may be attached to differentiate variables further. For example, you might encounter variable keys like `PSI.VariableKey{PSI.ActivePowerReserveVariable, VariableReserve{ReserveUp}}("Spin_Up_R3")` and `PSI.VariableKey{PSI.ActivePowerReserveVariable, VariableReserve{ReserveUp}}("Spin_Up_R1")`.


You can also inspect specific variable arrays, which are indexed by device name and time steps. For example:
```julia
# Inspect a variable array (replace with the desired variable key)
variables_dict[PSI.VariableKey{PSI.ActivePowerVariable, PSY.ThermalStandard}("")]
```

### Investigating Constraints
Constraints define the conditions and limitations that must be satisfied during the optimization process. They ensure that the solution adheres to physical and operational requirements. Here's how to investigate constraints in your simulation:

```julia
# Get a dictionary of all constraints in the optimization model
constraints_dict = PSI.get_constraints(optimization_cont)

# List all the constraints included in the optimization model
keys(constraints_dict)
```

Similar to variables, constraint arrays are indexed by device name and time steps. You can inspect specific constraints to understand their role in the simulation:

```julia
# Inspect a specific constraint array (replace with the desired constraint key)
constraints_dict[PSI.ConstraintKey{PSI.RampConstraint, PSY.ThermalStandard}("up")]["202_STEAM_3", :]
```
By exploring variables and constraints in your PowerSimulations model, you gain valuable insights into the optimization process, helping you interpret and analyze the simulation results effectively.

## Saving the JuMP Model

If you wish to delve deeper into the inner workings of your PowerSimulations model, you can save the entire JuMP Model to a text file. This can be a valuable tool for detailed inspection and analysis. However, please note that the resulting file size can grow quickly, especially for models with many time periods. Here's how you can save the JuMP Model to a text file:

```julia
# Save the JuMP Model to a text file
open("model.txt", "w") do f
    println(f, PSI.get_jump_model(optimization_cont))
end
```
Before running this code, it's advisable to consider the following:

- Depending on the complexity of your simulation, the resulting model file can be quite large. Reducing the number of time periods can help manage the file size and make it more manageable for analysis.
Saving the JuMP Model allows you to explore the model's structure and details, making it a useful resource for gaining insights into the optimization process.