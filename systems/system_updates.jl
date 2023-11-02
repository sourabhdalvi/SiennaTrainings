# Sienna System Modification Training Script

# This script demonstrates how to manipulate data in a System and provides a step-by-step guide to exploring different functionalities provided in the PowerSystems.jl package.

# Loading Sienna Packages and dependencies
using PowerSimulations
using InfrastructureSystems
using PowerSystems
const PSI = PowerSimulations
const PSY = PowerSystems
using DataFrames
using TimeSeries
using CSV
using Dates

# Loading the system
sys = PSY.System("data/RTS_GMLC_DA.json")

# Transforming Static Time Series into Forecasts
# In many modeling workflows, it's common to transform data generated from a realization and stored in a single column into deterministic forecasts.
# This transformation accounts for the effects of lookahead without duplicating data.
# transform_single_time_series!(sys, horizon, interval) where horizon is expected to be Int and Interval should be a time period.
transform_single_time_series!(sys, 48, Hour(24))

# Accessing Components
# You can access all the components of a particular type.
# Note that the return type of get_components is a FlattenIteratorWrapper, so you should call collect to get an Array.
get_components(Bus, sys) |> collect

# get_components also works on abstract types:
get_components(Branch, sys) |> collect

# Querying a Component by Name
# You can query a component by name:
get_component(StaticInjection, sys, "322_CT_6")

# Accessing Fields Within a Component
# To access fields within a component, it's highly recommended that users avoid using the . to access fields since we make no guarantees on the stability of field names and locations.
# We do, however, promise to keep the accessor functions stable.
bus1 = get_component(Bus, sys, "Baffin")
get_name(bus1)
get_magnitude(bus1)

# Removing a Specific Component
# You can remove a specific component:
remove_component!(sys, get_component(ThermalGen, sys, "322_CT_5"))
remove_component!(ThermalStandard, sys, "321_CC_1")

# Removing All Hydro Components
# Remove all hydro components from the system:
remove_components!(HydroDispatch, sys)

# Setting Components Offline
# To exclude components from the simulation without deleting them permanently, you can set them as unavailable.
# For example, here's how to set thermal generators with a maximum active power limit of 0.0 as unavailable:
for gen in
    PSY.get_components(x -> PSY.get_active_power_limits(x).max == 0.0, PSY.ThermalGen, sys)
    PSY.set_available!(gen, false)
end

# Advanced Query Example
# In this example, we demonstrate how to perform advanced queries by passing a filter function to get_components.
# This feature is a powerful tool for making bulk changes in the system, which can be especially handy for homework assignments.

# Querying Combined Cycle Thermal Generators
# 1. First, let's query all Combined Cycle thermal generators in the system:
gen =
    PSY.get_components(
        x -> PSY.get_prime_mover_type(x) == PSY.PrimeMovers.CC,
        PSY.ThermalGen,
        sys,
    ) |> first

# Querying Combined Cycle Thermal Generators in Region/Area 1
# 2. Next, we'll narrow it down and query all Combined Cycle thermal generators from Region/Area 1 in the system:
gen =
    PSY.get_components(
        x ->
            PSY.get_prime_mover_type(x) == PSY.PrimeMovers.CT &&
                PSY.get_name(PSY.get_area(PSY.get_bus(x))) == "1",
        PSY.ThermalGen,
        sys,
    ) |> first

# Querying Solar PV Plants
# 3. Suppose you want to query all solar PV plants from the system with a nameplate capacity between 50 MW and 150 MW.
# First, make sure the unit settings of the system are set to Natural units using:
PSY.set_units_base_system!(sys, PSY.UnitSystem.NATURAL_UNITS)
# Then, you can perform the query:
gens =
    PSY.get_components(
        x ->
            PSY.get_prime_mover_type(x) == PSY.PrimeMovers.PVe &&
                PSY.get_max_active_power(x) >= 50.0 &&
                PSY.get_max_active_power(x) <= 150.0,
        PSY.RenewableDispatch,
        sys,
    ) |> collect

# Querying Wind Plants
# 4. Now, let's perform a similar exercise, but this time for wind plants with a nameplate capacity above 100 MW:
gens =
    PSY.get_components(
        x ->
            PSY.get_prime_mover_type(x) == PSY.PrimeMovers.WT && PSY.get_rating(x) >= 100.0,
        PSY.RenewableDispatch,
        sys,
    ) |> collect

# Updating Device Parameters
# Here, we provide an example function to change the ramp rate of each thermal device in the system.
# You can easily modify this function by passing a filter function to apply it to specific groups of thermal generators.
function update_thermal_ramp_rates!(sys)
    for th in get_components(
        x -> PSY.get_prime_mover_type(x) == PSY.PrimeMovers.CT,
        ThermalGen,
        sys,
    )
        pmax = get_active_power_limits(th).max
        set_ramp_limits!(th, (up=(pmax * 0.2) / 60, down=(pmax * 0.2) / 60)) # Ramp rate is expected to be in MW/min
    end
    return
end

update_thermal_ramp_rates!(sys)

# Copying a Renewable Dispatch Component
# This code demonstrates how to create a copy of a RenewableDispatch component, customize it, and add it to the power system.
# Create a copy of a RenewableDispatch component
function copy_component(sys::PSY.System, re::PSY.RenewableDispatch, bus_name, name)
    # Get the bus associated with the specified name
    bus = PSY.get_component(Bus, sys, bus_name)

    # Create a new RenewableDispatch component as a copy
    device = PSY.RenewableDispatch(
        name=name,               # Set the name for the new component
        available=true,          # Mark the component as available
        bus=bus,                 # Assign the bus to the component
        active_power=get_active_power(re),                # Copy active power from the original component
        reactive_power=get_reactive_power(re),            # Copy reactive power from the original component
        rating=get_rating(re),                          # Copy the rating from the original component
        prime_mover_type=get_prime_mover_type(re),                # Copy the prime mover from the original component
        reactive_power_limits=get_reactive_power_limits(re),  # Copy reactive power limits
        power_factor=get_power_factor(re),              # Copy power factor
        operation_cost=get_operation_cost(re),          # Copy operation cost
        base_power=get_base_power(re),                  # Copy base power
    )

    return device  # Return the newly created component
end

# Creating a copy of the device to add new capacity to the system.
pv = first(
    get_components(
        x -> x.prime_mover_type == PSY.PrimeMovers.PVe,
        PSY.RenewableDispatch,
        sys,
    ),
)
device = copy_component(sys, pv, PSY.get_name(PSY.get_bus(pv)), "new_PV")  # Create a new PV component as a copy

# Adding the new component to the system
add_component!(sys, device)  # Add the new PV component to the system

# Copying over the time series data from the original device to the new device.
copy_time_series!(device, pv)  # Copy time series data from the original PV device to the new PV device

# TODO: example with shared references on Variable cost

# Adding a New Battery Component
# This code demonstrates how to create a new battery component, customize its parameters, and add it to the power system.

# Adding New Components
function _build_battery(
    ::Type{T},
    bus::PSY.Bus,
    name::String,
    energy_capacity,
    rating,
    efficiency,
) where {T <: PSY.Storage}
    # Create a new storage device of the specified type
    device = T(
        name=name,                         # Set the name for the new component
        available=true,                    # Mark the component as available
        bus=bus,                           # Assign the bus to the component
        prime_mover_type=PSY.PrimeMovers.BA,    # Set the prime mover to Battery
        initial_energy=energy_capacity / 2,  # Set initial energy level
        state_of_charge_limits=(min=energy_capacity * 0.1, max=energy_capacity),  # Set state of charge limits
        rating=rating,                     # Set the rating
        active_power=rating,               # Set active power equal to rating
        input_active_power_limits=(min=0.0, max=rating),  # Set input active power limits
        output_active_power_limits=(min=0.0, max=rating),  # Set output active power limits
        efficiency=(in=efficiency, out=1.0),  # Set efficiency
        reactive_power=0.0,                # Set reactive power
        reactive_power_limits=nothing,      # No reactive power limits
        base_power=100.0,                   # Set base power
    )

    return device  # Return the newly created component
end

# Creating a copy of the device to add new capacity to the system.
bus = PSY.get_bus(
    first(
        get_components(
            x ->
                PSY.get_prime_mover_type(x) == PSY.PrimeMovers.PVe &&
                    PSY.get_max_active_power(x) >= 150.0,
            PSY.RenewableDispatch,
            sys,
        ),
    ),
)
device = _build_battery(GenericBattery, bus, "new_battery", 10.0, 2.5, 0.8)  # Create a new battery component

add_component!(sys, device)  # Add the new battery component to the system

# Converting Thermal Devices
# To convert thermal devices from ThermalStandard to ThermalMultiStart, use the PSY.convert_component! function.
# This is often used to set devices as "must-run" units in the Unit Commitment (UC) problem.

function PSY.convert_component!(
    thtype::Type{PSY.ThermalMultiStart},
    th::ThermalStandard,
    sys::System;
    kwargs...,
)
    # Converting Thermal Devices (Continued)
    # Arguments:
    # - `thtype::Type{PSY.ThermalMultiStart}` specifies the target type (`ThermalMultiStart`).
    # - `th::ThermalStandard` represents the thermal device you want to convert.
    # - `sys::System` is your power system model.
    # - `kwargs...` are additional keyword arguments.

    new_th = thtype(
        name=PSY.get_name(th),
        available=true,
        status=PSY.get_status(th),
        bus=PSY.get_bus(th),
        active_power=PSY.get_active_power(th),
        reactive_power=PSY.get_reactive_power(th),
        rating=PSY.get_rating(th),
        prime_mover_type=PSY.get_prime_mover_type(th),
        fuel=PSY.get_fuel(th),
        active_power_limits=PSY.get_active_power_limits(th),
        reactive_power_limits=PSY.get_reactive_power_limits(th),
        ramp_limits=PSY.get_ramp_limits(th),
        time_limits=PSY.get_time_limits(th),
        power_trajectory=nothing,
        start_time_limits=nothing,
        start_types=1,
        operation_cost=PSY.get_operation_cost(th),
        base_power=PSY.get_base_power(th),
        services=Device[],
        must_run=true,
        time_at_status=PSY.get_time_at_status(th),
        dynamic_injector=PSY.get_dynamic_injector(th),
        ext=Dict{String, Any}(),
    )
    PSY.add_component!(sys, new_th)
    PSY.copy_time_series!(new_th, th)
    new_th.ext = th.ext

    # Transfer over the same service eligibility
    for service in PSY.get_services(th)
        PSY.add_service!(new_th, service, sys)
    end

    # Remove old device from system
    PSY.remove_component!(sys, th)

    return
end

# Converting Nuclear Devices
# To convert all nuclear devices in your system, use the `convert_must_run_units!` function.
# This ensures that nuclear units are set as "must-run" units in your UC problem.

function convert_must_run_units!(sys)
    for d in
        PSY.get_components(x -> x.fuel == PSY.ThermalFuels.NUCLEAR, PSY.ThermalGen, sys)
        PSY.convert_component!(PSY.ThermalMultiStart, d, sys)
    end
end

convert_must_run_units!(sys)

# Adding Reserves to the System
# The `add_reserves` function allows you to add reserve capacity to your system, which is essential for maintaining grid reliability.
function add_reserves(sys; reserve_frac=0.1)
    PSY.set_units_base_system!(sys, PSY.UnitSystem.NATURAL_UNITS)
    power_loads = PSY.get_components(PSY.PowerLoad, sys)
    reserve_ts = zeros(8784)
    TS = nothing

    for p in power_loads
        ts = PSY.get_time_series_values(PSY.SingleTimeSeries, p, "max_active_power")
        reserve_ts .= reserve_ts .+ ts .* reserve_frac
        TS = PSY.get_time_series_timestamps(PSY.SingleTimeSeries, p, "max_active_power")
    end

    service = PSY.VariableReserve{PSY.ReserveUp}(
        name="new_reserve",
        available=true,
        time_frame=1.0,
        requirement=maximum(reserve_ts) / 100,
    )

    contri_devices =
        PSY.get_components(x -> !(typeof(x) <: PSY.StaticLoad), PSY.StaticInjection, sys)
    PSY.add_service!(sys, service, contri_devices)

    PSY.add_time_series!(
        sys,
        service,
        PSY.SingleTimeSeries(
            "requirement",
            TimeSeries.TimeArray(TS, reserve_ts ./ maximum(reserve_ts)),
            scaling_factor_multiplier=PSY.get_requirement,
        ),
    )

    return
end

add_reserves(sys; reserve_frac=0.05)

## Next step is to update contributing devices for reserves.
# Ensure storage eligibility, filtering StaticInjection,
# excluding StaticLoad & StaticInjectionSubSystem.

function update_contributing_devices!(sys, service)
    area_name = last(split(service.name, "_"))
    contributing_devices = PSY.get_components(
        x -> (
            x.bus.load_zone.name == area_name &&
            !(typeof(x) <: PSY.StaticLoad) &&
            !(typeof(x) <: PSY.StaticInjectionSubsystem)
        ),
        PSY.StaticInjection,
        sys,
    )
    for device in contributing_devices
        PSY.add_service!(device, service, sys)
    end
    return
end

function update_service_contributions!(sys)
    for service in PSY.get_components(PSY.VariableReserve, sys)
        update_contributing_devices!(sys, service)
    end
    return
end

update_service_contributions!(sys)

# Example Function: Generating Timestamps
# Here's a simple Julia function, `get_day_ahead_timestamps`, for generating timestamps, which can be helpful for adding time series data:

function get_day_ahead_timestamps(sim_year)
    return collect(
        DateTime("$(sim_year)-01-01T00:00:00"):Hour(1):DateTime(
            "$(sim_year)-12-31T23:00:00",
        ),
    )
end

# Modifying Time Series Data
# Updating Wind Generation Time Series
# The `update_wind_timeseries!` function allows you to modify the time series data for wind generation.
# In this example, we reduce wind generation by 5%, but you can adapt this workflow for other adjustments.
function update_wind_timeseries!(sys)
    # Set the units of the power system to natural_units (common in power system modeling)
    PSY.set_units_base_system!(sys, "natural_units")

    # Define the simulation year
    sim_year = 2020

    # Generate timestamps for the entire year based on the simulation year
    TS = get_day_ahead_timestamps(sim_year)

    # Iterate through all renewable dispatch components (likely wind turbines) in the power system
    for re in PSY.get_components(
        x -> PSY.get_prime_mover_type(x) == PSY.PrimeMovers.WT,
        PSY.RenewableDispatch,
        sys,
    )
        # Get the maximum active power limit for the current wind generation component
        max_active_power = PSY.get_max_active_power(re)

        # Iterate through all time series associated with the current wind generation component
        for ts_name in PSY.get_time_series_names(PSY.SingleTimeSeries, re)
            # Retrieve the original time series data and reduce it by 5%
            ts_data = PSY.get_time_series_values(PSY.SingleTimeSeries, re, ts_name) .* 0.95

            # Remove the original time series data
            PSY.remove_time_series!(sys, PSY.SingleTimeSeries, re, ts_name)

            # Create a new time series with the updated data
            new_st = PSY.SingleTimeSeries(
                name=ts_name,
                data=TimeArray(TS, ts_data),
                scaling_factor_multiplier=PSY.get_max_active_power,
            )

            # Add the newly created time series back to the power system
            PSY.add_time_series!(sys, re, new_st)
        end
    end

    # The function does not explicitly return a value but updates the wind generation time series data in the power system.
    return
end

update_wind_timeseries!(sys)

## Write final system to disk to save all changes.
PSY.to_json(sys, "data/RTS_GMLC_DA_test_modifications.json")


##
