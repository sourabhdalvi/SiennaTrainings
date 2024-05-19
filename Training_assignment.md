# SiennaAnalysis Homework Assignment

Welcome to the SiennaAnalysis homework assignment repository. This assignment is designed to help you become proficient in using Sienna-Ops for building and simulating an RTS (Regional Transmission System) system. Below are the tasks and instructions for this assignment.

## System Modifications Tasks

1. **Converting Nuclear Device:** Change the RTS Nuclear device from ThermalStandard to ThermalMultiStart and set it as a must-run unit.

2. **Adding PV Devices:** Add new PV devices with a combined capacity of 2500 MW. You can use templates like 319_PV_1, 215_PV_1, 314_PV_4, or others. The bus you add these devices to doesn't matter, as we will run Copper Plate network simulations.

3. **Adding Wind Devices:** Add new Wind devices with a combined capacity of 2000 MW. Feel free to use templates like 317_WIND_1, 309_WIND_1, or others. The bus doesn't matter for this exercise.

4. **Adding a Reserve:** Introduce a new Reserve in the system to hold 3% of forecasted load, 5% of  PV and Wind forecasted generation.

5. **Adding Energy Storage Devices:**
   - Add a Short Duration Energy Storage (SDES) device with these parameters: energy capacity = 640 MWh, input/output power rating = 160, input efficiency = 85%, and output efficiency = 100%.
   - Add a Long Duration Energy Storage (LDES) device with these parameters: energy capacity = 5700 MWh, input/output power rating = 380, input efficiency = 65%, and output efficiency = 100%.

6. **Thermal Generator Initialization:** Update the initial condition of each Thermal Generator, setting their status to offline at the start of the simulation and having been offline for 999 hours.

7. **Battery Initialization:** Set the initial state of charge for all battery devices to 50% of their maximum state of charge.

## Simulation Scenarios

All simulation scenarios should start on July 1st.

- **Base Case Scenario:** Run a single-stage simulation with the base RTS system. Set the horizon to 48 hours, interval to 24 hours, and steps to 30.

- **High PV Scenario:** Run a single-stage simulation with the base RTS system, considering high PV generation. Use the same settings as the base case scenario.

- **High PV + Wind Scenario:** Run a single-stage simulation with the base RTS system, considering high PV and Wind generation. Use the same settings as the base case scenario.

- **High PV + Wind + SDES Scenario:** Run a single-stage simulation with the base RTS system, considering high PV, Wind, and Short Duration Energy Storage (SDES). Use the same settings as the base case scenario.

- **High PV + Wind + SDES + LDES Scenario:** Run a single-stage simulation with the base RTS system, considering high PV, Wind, Short Duration Energy Storage (SDES), and Long Duration Energy Storage (LDES). Use the same settings as the base case scenario.

## Scenario Analysis

The objective of this analysis is to compare the outputs from the simulation scenarios in a structured dataframe. The dataframe should include the following metrics:

- Total System Cost
- Production Cost (for Thermal Devices)
- Thermal Generation
- PV Generation
- Wind Generation
- Storage/Battery Charging
- Storage/Battery Discharging
- Curtailment
- Storage Cycles

Additionally, provide summary statistics for the scenarios. Finally, create a dispatch stack plot for the peak load day in the month of July, including one day before and after.

Follow these tasks to complete your SiennaAnalysis homework assignment. Have a great learning experience!
