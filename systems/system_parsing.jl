# Tutorial: Building Sienna System Objects using PowerSystems.jl

using PowerSystems
using PowerSimulations
using PowerSystemCaseBuilder

const PSB = PowerSystemCaseBuilder
const PSY = PowerSystems

# Introduction:
# -------------
# In this script, we leverage the Power Systems Test Data, a curated set of 
# test systems. These systems assist in:
# 1) Helping the Sienna development team test new features.
# 2) Offering users a starting point for understanding and exploring Sienna.

# Accessing Test Data:
# --------------------
# Several RAW file examples are available, but here, we'll copy the current set.
readdir(joinpath(PSB.DATA_DIR, "psse_raw"))

# Copy the RTS-GMLC raw file to our data directory.
cp(joinpath(PSB.DATA_DIR, "psse_raw", "RTS-GMLC.RAW"), "data/RTS-GMLC.RAW")

# Similarly, copy the RTS-GMLC MATPOWER file.
readdir(joinpath(PSB.DATA_DIR, "matpower"))
cp(joinpath(PSB.DATA_DIR, "matpower", "RTS_GMLC.m"), "data/RTS_GMLC.m")

# Copy all RTS-GMLC data.
RTS_GMLC_DIR = joinpath(PSB.DATA_DIR, "RTS_GMLC")
cp(RTS_GMLC_DIR, "data/RTS_GMLC")

# Parsing Files:
# --------------
# We'll parse different formats to create an initial Sienna System Object, 
# leveraging PowerSystems.jl's built-in parsing capability.

# Example 1: Parsing a PSSE RAW File
# PSSE primarily stores network-related info. Devices will be parsed as 
# ThermalStandard, which can later be converted to other generator types. 
# The parser currently supports up to v33 of the PSSE RAW format.
sys_psse = System("./data/RTS-GMLC.RAW")

# Example 2: Parsing a Matpower .m File
# Comprehensive data in Matpower allows for a complete PCM system build in one step.
sys_matpower = System("./data/RTS_GMLC.m")

# Example 3: Parsing Tabular Data Format
# This format uses .CSV files for each infrastructure type (e.g., bus.csv). 
# It also supports parsing of time series data. The format allows flexibility in 
# data representation and storage.
rawsys = PSY.PowerSystemTableData(
    RTS_GMLC_DIR,
    100.0,
    joinpath(RTS_GMLC_DIR, "user_descriptors.yaml");
    timeseries_metadata_file = joinpath(RTS_GMLC_DIR, "timeseries_pointers.json"),
    generator_mapping_file = joinpath(RTS_GMLC_DIR, "generator_mapping.yaml"),
)
sys = PSY.System(rawsys; time_series_resolution = Dates.Hour(1), sys_kwargs...)
PSY.transform_single_time_series!(sys, 24, Dates.Hour(24))

