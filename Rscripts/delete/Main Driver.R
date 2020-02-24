# Main Driver
library(rstudioapi)

# Clear all memory
rm(list = ls())

# Start the clock!
ptm <- proc.time()

current_working_dir <- dirname(rstudioapi::getActiveDocumentContext()$path)
setwd(current_working_dir)

# Part 1
# ________________________________________
# Curve fitting function

# Sample input for curve fitting function:
# Average DSD fit data:
y<-c( 0.000000,	0.000567,	0.002167,	0.005800,	0.011267,	0.018667,	0.031733,	0.053300,	0.086867,	0.128467,	0.194733,	0.291667,	0.421867,	0.581300,	0.759500,	0.933300,	0.999900,	1.000000)
y<-100*y
# Corresponding droplet size (in microns):
Dpdata<-c( 86, 100, 120, 150, 180, 210, 250, 300, 360, 410, 500, 600, 720, 860, 1020, 1220, 1460, 1740)

# Call curve fitting function
source("1_psd_function.R")

# The following contains the fitted parameters of the drop size distribution model
pars<-psd(y,Dpdata)


# Part 2
# ________________________________________
# Wet Bulb Calculations
source("2_wet_bulb_function.R")

# The following contains the wet bulb temperature
# Inputs are in sequence Dry air temperature, ?C, Barometric pressure, mmHg abs and Percent relative humidity
# Outputs are: DTwb,Twb

Twb<-wet_bulb(17.689,760,35.65)  


# Part 3
# ________________________________________
# 
source("3_wvprofile_params.R")
# Inputs are lambda (fraction vegetation), canopy height (inches), boom height (inches), and wind speed (mph)/height (feet)
# Outputs are Uh, Ufriction, z1, z0, alpha_avg, k2
#***[SFR - changed the name of the object because profile is a base function]
wvprofile_params<-WV2m(0.08, 4, 20, 6.6, 12.8)

#### Need to add part for when we have two measurements.

# Part 4
# ________________________________________
# Droplet Transport
source ("4_Droplet_Transport_function.R")

a<-droplet_transport()


# Part 5
# ________________________________________
source("5_Deposition_Calcs_function.R")

deposition_calcs()


# Stop the clock
proc.time() - ptm  # 220 secs for non-parallel code;


# Part 6
# ________________________________________
# Sample Plots

