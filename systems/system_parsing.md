# Tutorial: Building Sienna System Objects using PowerSystems.jl

In this tutorial, we will demonstrate how to construct Sienna System Objects using the PowerSystems.jl package.

## Setup and Dependencies

First, let's import the necessary packages:

```julia
using PowerSystems
using PowerSimulations
using PowerSystemCaseBuilder

const PSB = PowerSystemCaseBuilder
const PSY = PowerSystems
```

## Introduction

We will utilize the Power Systems Test Data, a curated set of test systems. These test systems serve two primary purposes:

 1. Assisting the Sienna development team in testing new features.
 2. Providing users a springboard to learn and explore Sienna.

## Accessing Test Data
All of the Power Systems Test Data is hosted in a [PowerSystemsTestData](https://github.com/NREL-Sienna/PowerSystemsTestData) GitHub repo. But for this tutorial we will just use a version of the this data downloaded by PowerSystemCaseBuiler package.
Below is an example on how we can access this dataset for extracting a PSSE RAW file.
```julia
readdir(joinpath(PSB.DATA_DIR, "psse_raw"))
```
For this tutorial, we will focus on the RTS-GMLC system and copy the raw file to our data directory:

```julia
cp(joinpath(PSB.DATA_DIR, "psse_raw", "RTS-GMLC.RAW"), "data/RTS-GMLC.RAW")
```

## Parsing Files

The next step involves parsing different file formats to construct an initial Sienna System Object. We'll harness PowerSystems.jl's innate parsing capability.

### Example 1: Parsing a PSSE RAW File

PSSE primarily retains network-related information. Initially, we will parse devices as `ThermalStandard`, but they can be later modified to other generator types. Note that the parser currently supports up to v33 of the PSSE RAW format:

```julia
sys_psse = System("./data/RTS-GMLC.RAW")
```

### Example 2: Parsing a Matpower .m File

We will  copy the MATPOWER version of the RTS-GMLC data as for this example.

```julia
readdir(joinpath(PSB.DATA_DIR, "matpower"))
cp(joinpath(PSB.DATA_DIR, "matpower", "RTS_GMLC.m"), "data/RTS_GMLC.m")
```

Matpower's comprehensive dataset allows for a one-step complete PCM system build:

```julia
sys_matpower = System("./data/RTS_GMLC.m")
```

### Example 3: Parsing Tabular Data Format

Lastly, let's copy all data related to RTS-GMLC Tabular Dataset:

```julia
cp(joinpath(PSB.DATA_DIR, "RTS_GMLC"), "data/RTS_GMLC")
RTS_GMLC_DIR = "data/RTS_GMLC"
```


This format adopts .CSV files for different infrastructure types, like `bus.csv`. Moreover, it facilitates the parsing of time series data, granting users substantial flexibility in data representation and storage:

```julia
rawsys = PSY.PowerSystemTableData(
    RTS_GMLC_DIR,
    100.0,
    joinpath(RTS_GMLC_DIR, "user_descriptors.yaml");
    timeseries_metadata_file=joinpath(RTS_GMLC_DIR, "timeseries_pointers.json"),
    generator_mapping_file=joinpath(RTS_GMLC_DIR, "generator_mapping.yaml"),
)
sys = PSY.System(rawsys; time_series_resolution=Dates.Hour(1), sys_kwargs...)
PSY.transform_single_time_series!(sys, 24, Dates.Hour(24))
```

## Conclusion

By following this tutorial, users should be equipped to leverage PowerSystems.jl for the creation of Sienna System Objects. This foundation will enable further exploration and utilization of the Sienna framework.
