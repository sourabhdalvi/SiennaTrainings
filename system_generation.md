# Sienna System Generation Training Script

This script demonstrates how to use the PowerSystemsCaseBuilder.jl package and provides a step-by-step guide to explore and build power system models.

## Introduction

In this script, we will utilize the PowerSystemsCaseBuilder.jl package, which houses a curated set of test systems. These test systems serve two primary purposes:

1. They assist the Sienna development team in testing new features.
2. They provide users with access to these test systems to facilitate their journey of learning and exploring Sienna.

## Step 1: Show All Systems for All Categories

To begin, we can list all the available test systems using the `show_systems()` function.

```julia
using PowerSystemCaseBuilder
show_systems()
```

## Step 2: Show All Categories

Next, let's explore the various categories available for these test systems.

```julia
using PowerSystemCaseBuilder
show_categories()
```

## Step 3: Show All Systems for One Category

Now, we can delve deeper into a specific category, such as `PSISystems`, to see the systems it contains.

```julia
using PowerSystemCaseBuilder
show_systems(PSISystems)
```

## Step 4: Build a System

Let's proceed by building a specific system from the available test systems. When doing so, two crucial arguments to consider are:

1. `time_series_directory`: While not required for local machine usage, it's necessary when running on NREL's HPC systems (Eagle or Kestrel). Users should pass `time_series_directory="/tmp/scratch"` as an argument.

2. `time_series_read_only`: This option loads the system in read-only mode, which can be helpful when dealing with large datasets. If you wish to edit time series information, do not use this option.

Here, we build two systems as examples:

1. The first system is the RTS Day-ahead system, which contains hourly time series data.

```julia
sys_da = PSB.build_system(PSISystems, "modified_RTS_GMLC_DA_sys";
                       time_series_directory="/tmp/scratch")
```

2. The second system is the RTS Real-time system, featuring 5-minute time series data.

```julia
sys_rt = PSB.build_system(PSISystems, "modified_RTS_GMLC_RT_sys";
                       time_series_directory="/tmp/scratch")
```

## Step 5: Save the System to JSON

Finally, we can save the system data to a JSON file for further analysis.

```julia
PSY.to_json(sys_da, "data/RTS_GMLC_DA.json")
PSY.to_json(sys_rt, "data/RTS_GMLC_RT.json")
```

This script provides a foundation for working with Sienna's power system models, exploring available test systems, and building custom models for analysis and simulation.

