# Tutorial: Building Sienna System Objects using PowerSystems.jl

using PowerSystems
using PowerSimulations
using PowerSystemCaseBuilder
using Dates
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
# All of the Power Systems Test Data is hosted in a [PowerSystemsTestData](https://github.com/NREL-Sienna/PowerSystemsTestData) GitHub repo. But for this tutorial we will just use a version of the this data downloaded by PowerSystemCaseBuiler package.
# Below is an example on how we can access this dataset for extracting a PSSE RAW file.
readdir(joinpath(PSB.DATA_DIR, "psse_raw"))

mkdir("data")

# For this tutorial, we will focus on the RTS-GMLC system and copy the raw file to our data directory:
cp(joinpath(PSB.DATA_DIR, "psse_raw", "RTS-GMLC.RAW"), "data/RTS-GMLC.RAW")

# Parsing Files:
# --------------
# We'll parse different formats to create an initial Sienna System Object, 
# leveraging PowerSystems.jl's built-in parsing capability.

# Example 1: Parsing a PSSE RAW File
# PSSE primarily stores network-related info. Devices will be parsed as 
# ThermalStandard, which can later be converted to other generator types. 
# The parser currently supports up to v33 of the PSSE RAW format.
sys_psse = PSY.System("./data/RTS-GMLC.RAW") 
    # bus_name_formatter = x->string(strip(x["name"])*"_"*string(x["index"])),
    # load_name_formatter = x-> x["source_id"][1]*"_$(x["source_id"][2])~"*strip(x["source_id"][3]),
    # branch_name_formatter = x-> x["source_id"][1]*"_$(x["source_id"][2])~"*strip(x["source_id"][4]),
# )

# Example 2: Parsing a Matpower .m File
# We will  copy the MATPOWER version of the RTS-GMLC data as for this example.

readdir(joinpath(PSB.DATA_DIR, "matpower"))
cp(joinpath(PSB.DATA_DIR, "matpower", "RTS_GMLC.m"), "data/RTS_GMLC.m")

# Comprehensive data in Matpower allows for a complete PCM system build in one step.
sys_matpower = System("data/RTS_GMLC.m")

# Example 3: Parsing Tabular Data Format

# Lastly, let's copy all data related to RTS-GMLC Tabular Dataset:
cp(joinpath(PSB.DATA_DIR, "RTS_GMLC"), "data/RTS_GMLC")
RTS_GMLC_DIR =  "data/RTS_GMLC"

# This format uses .CSV files for each infrastructure type (e.g., bus.csv). 
# It also supports parsing of time series data. The format allows flexibility in 
# data representation and storage.
rawsys = PSY.PowerSystemTableData(
    RTS_GMLC_DIR,
    100.0,
    joinpath(RTS_GMLC_DIR, "user_descriptors.yaml");
    timeseries_metadata_file=joinpath(RTS_GMLC_DIR, "timeseries_pointers.json"),
    generator_mapping_file=joinpath(RTS_GMLC_DIR, "generator_mapping.yaml"),
)
sys = PSY.System(rawsys; time_series_resolution=Dates.Hour(1))
PSY.transform_single_time_series!(sys, 24, Dates.Hour(24))
