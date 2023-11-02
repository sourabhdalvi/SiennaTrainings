using PowerSimulations
using PowerSystems
const PSI = PowerSimulations
const PSY = PowerSystems
using DataFrames
using TimeSeries
using CSV
using Dates

results_path = ## add the path to the results directory
sys = PSY.System("data/RTS_GMLC_DA.json");
transform_single_time_series!(sys, 24, Hour(24))

results = SimulationResults(path; ignore_status=true);
results_uc = get_decision_problem_results(results, "UC");
set_system!(results_uc, sys);

# Reading the solution from Sienna
variables = PSI.read_realized_variables(results_uc)
aux_variables = PSI.read_realized_aux_variables(results_uc)
duals  = PSI.read_realized_duals(results_uc)
expressions = PSI.read_realized_expressions(results_uc)

## Calculating Production cost for Thermal Generators
function calculate_production_cost(result; start_time=DateTime("2030-01-01T00:00:00"), periods=8760)
    sys_cost = 0
    string_name = "ProductionCostExpression__ThermalStandard"
    df = PSI.read_realized_expressions(result, [(ProductionCostExpression, ThermalStandard)], start_time = start_time, len = periods)[string_name]
    for d in get_components(get_available, ThermalStandard, result.system)
        name = get_name(d)
        sys_cost += sum(df[:, name])
    end
    return sys_cost
end

calculate_production_cost(results_uc)

## Calculating the Amount of Dropped load 
function calculate_dropped_load(result; start_time=DateTime("2030-01-01T00:00:00"), periods=8760)
    drop_load = 0
    string_name = "SystemBalanceSlackUp__System"
    df = read_realized_variables(result, [(SystemBalanceSlackUp, System)], start_time = start_time, len = periods)[string_name]
    for row in eachrow(df)
        drop_load += sum(row[2:end])
    end
    return drop_load
end

calculate_drop_load(results_uc)


## Calculate total wind generation
function calculate_wind_generation(result, start_time=DateTime("2024-01-01T00:00:00"), periods=8760)
    gen = 0
    string_name = PSI.encode_key_as_string(ActivePowerVariable)
    df = read_realized_variables(result, [ActivePowerVariable], start_time, periods)[string_name]
    for d in get_components(x-> x.prime_mover == PrimeMovers.WT, RenewableDispatch, result.system)
        name = get_name(d)
        gen += sum(df[:, name])
    end
    return gen
end

calculate_wind_generation(results_uc)

## Calculate Wind capacity factor
function calculate_wind_capacity_factor(result, start_time=DateTime("2024-01-01T00:00:00"), periods=8760)
    string_name = PSI.encode_key_as_string(ActivePowerTimeSeriesParameter)
    df = read_realized_parameters(result, [ActivePowerTimeSeriesParameter], start_time, periods)[string_name]
    avg_capacity_factor = []
    for d in get_components(x-> x.prime_mover == PrimeMovers.WT, RenewableDispatch, result.system)
        name = get_name(d)
        rating = get_rating(d)
        push!(avg_capacity_factor, sum(df[:, name])/ (rating*periods))
    end
    return sum(avg_capacity_factor)/length(avg_capacity_factor) * 100
end

calculate_wind_capacity_factor(results_uc)

## Calculate RE curtailment MW and %
function calculate_RE_curtailment(result, start_time=DateTime("2024-01-01T00:00:00"), periods=8760)
    gen = 0
    forecast = 0
    df = read_realized_variables(result, [ActivePowerVariable], start_time, periods)[PSI.encode_key_as_string(ActivePowerVariable)]
    df_param = read_realized_parameters(result, [ActivePowerTimeSeriesParameter], start_time, periods)[PSI.encode_key_as_string(ActivePowerTimeSeriesParameter)]
    for row in eachrow(df)
        gen += sum(row[2:end])
    end
    for row in eachrow(df_param)
        forecast += sum(row[2:end])
    end
    return (forecast - gen), ((forecast - gen) / forecast) * 100
end

calculate_RE_curtailment(results_uc)

## Calculate Storage Cycles
function calculate_storage_cycles(result, var, start_time=DateTime("2024-01-01T00:00:00"), periods=8760 category_func)
    discharge = 0
    df = read_realized_variables(result, [ActivePowerOutVariable], start_time, periods)[PSI.encode_key_as_string(ActivePowerOutVariable)]
    names = get_name.(get_components(GenericBattery, result.system))
    soc_max = sum(map(x-> get_state_of_charge_limits(x).max, get_components(GenericBattery, result.system)))
    for row in eachrow(df)
        discharge += sum(row[names])
    end
    return (discharge, discharge / soc_max)
end

calculate_storage_cycles(results_uc)
