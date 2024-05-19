using PowerSystems
using PowerSimulations
using PowerSystemCaseBuilder
const PSB = PowerSystemCaseBuilder
const PSY = PowerSystems
# Introduction
# In this script, we will use the PowerSystemsCaseBuilder.jl package,
# which hosts a curated set of test systems. These test systems serve two
# main purposes: 1) They help the Sienna development team test new features.
# 2) They provide users access to these test systems to begin their journey
# of learning and exploring Sienna.

# Step 1: Show all systems for all categories
# We can start by listing all the available test systems.
show_systems()

# Step 2: Show all categories
# Let's see what categories are available for these test systems.
show_categories()

# Step 3: Show all systems for one category
# Now, let's explore the systems within a specific category, e.g., PSISystems.
show_systems(PSISystems)

# Step 4: Build a system
# Let's build a specific system from the available test systems.
# Two key arguments that users need to be aware of are:
# 1) `time_series_directory`: It isn't required when running on a local
# machine but is necessary when running on NREL's HPC systems (Eagle or
# Kestrel). Users should pass `time_series_directory="/tmp/scratch"`.
# 2) `time_series_read_only`: This option loads the system in read-only
# mode, which helps when loading large datasets. Don't use this if you want
# to edit time series information.
# The first system is the RTS Day-ahead system that contains hourly time
# series data.

sys_da = PSB.build_system(PSISystems, "modified_RTS_GMLC_DA_sys")
# The second system is the RTS Real-time system that contains 5-minute
# time series data.
sys_rt = PSB.build_system(PSISystems, "modified_RTS_GMLC_RT_sys")

# Step 5: Save the system to JSON
# We can save the system data to a JSON file for further analysis.
PSY.to_json(sys_da, "data/RTS_GMLC_DA.json")
PSY.to_json(sys_rt, "data/RTS_GMLC_RT.json")