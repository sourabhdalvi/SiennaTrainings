# Sienna Training Repository

Welcome to the Sienna Training Repository! This repository offers a comprehensive set of training exercises to help you become proficient in using Sienna for grid modeling.

**Getting Started**

Before you delve into these exercises, we highly recommend exploring the tutorials available in the [PowerSystems.jl](https://nrel-sienna.github.io/PowerSystems.jl/stable/) and [PowerSimulations.jl](https://nrel-sienna.github.io/PowerSimulations.jl/latest/) documentation. These tutorials provide valuable insights into the core concepts and functionalities of Sienna.

**Software Requirement**
These Training scripts require Julia version 1.8.x and above and PowerSystems.jl at 3.x or higher and PowerSimulations at 0.23.x or higher.
Before running any of the training scripts, to setup the julia env you will have to run the following commands. 
```julia
using Pkg
Pkg.activate(".")
Pkg.instantiate()
```

**Training Exercises**

Here's a structured sequence for your training:

1. **System Generation (`system_generation.jl`):** Begin by generating the RTS model using this script. This step sets up the foundational framework for your grid modeling exercises.

2. **System Updates (`system_updates.jl`):** Dive into querying data from the generated system and learn how to modify various aspects of it. This exercise helps you understand how to make adjustments to the system according to your modeling requirements.

3. **Single-Stage Simulations (`SingleStage_simulation.jl` and `SingleStage_simulation_detailed.jl`):** Explore how to set up single-stage simulations using these scripts. They serve as excellent examples to kickstart your journey into simulation configuration.

4. **Multi-Stage Simulations (`MultiStage_simulation.jl` and `MultiStage_simulation_detailed.jl`):** These scripts guide you through constructing multi-stage simulations. Learn how to use feedforwards to pass information between different stages of your simulations, a crucial skill for tackling complex modeling scenarios.

5. **Analysis (`analysis_template.jl`):** Once you've run simulations, this script demonstrates how to query the results and organize them into dataframes. You'll learn how to calculate various metrics related to system dispatch, operational costs, and more.

6. **Troubleshooting (Coming Soon):** We will delve into basic debugging methods to handle infeasible scenarios or address potential issues with system data, such as missing or incorrect values.

**Optional Commerical Solver Setup**

Please note that for running Sienna on moderately sized systems, it is highly recommended to set up Xpress on your local machine. You can find detailed instructions on how to install it and acquire a license file in the [Xpress Setup Guide](https://github.nrel.gov/bknueven/fico-xpress). If you cannot complete this setup before the tutorial, you can always use an open-source solver (although it will be slightly slower) or run it on Eagle where Xpress is available using `module load xpressmp`. We will also update the code base later tonight to support both solvers. If you encounter any issues while setting up the license, please do not hesitate to reach out.

Feel free to explore these exercises at your own pace. They are designed to progressively enhance your skills in Sienna grid modeling. Enjoy your learning journey!

## Previously Recorded Trainings
-**Trainings Part-1**: Covers Introduction to PowerSystems and explores its functionality; the recording can be found [here](https://nrel-my.sharepoint.com/:v:/g/personal/sdalvi_nrel_gov/EZJoXT7LI6NIl2YNQd9nJWoBBZezzAgGE4RJyUnDgZ_F2g?e=Tv77Vg&nav=eyJyZWZlcnJhbEluZm8iOnsicmVmZXJyYWxBcHAiOiJTdHJlYW1XZWJBcHAiLCJyZWZlcnJhbFZpZXciOiJTaGFyZURpYWxvZyIsInJlZmVycmFsQXBwUGxhdGZvcm0iOiJXZWIiLCJyZWZlcnJhbE1vZGUiOiJ2aWV3In19)