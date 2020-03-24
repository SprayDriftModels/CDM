# Main Driver
# Load Libraries
library(rstudioapi)
library(nlstools)
library(nleqslv)
library(deSolve)
library(doParallel)
library(foreach)
library(ggplot2)
library(gridExtra)
library(tidyverse)

# Clear all memory
rm(list = ls())

# Remove all figures
graphics.off()

# Start the clock
ptm <- proc.time()

current_working_dir <- dirname(rstudioapi::getActiveDocumentContext()$path)
setwd(current_working_dir)

echo = T

# Open Input properties
source("Inputs.R")


# Part 1
# ________________________________________
# Curve fitting function
# Call curve fitting function
source("1_psd_function.R")
# The following contains the fitted parameters of the drop size distribution model
pars<-psd(y,Dpdata)

# Plot calibration
x11()
pars$plot


# Part 2
# ________________________________________
# Wet Bulb Calculations
source("2_wet_bulb_function.R")
Twb<-wet_bulb(Tair,Patm,RH)  


# Part 3
# ________________________________________
# 
source("3_wvprofile_params.R")

# Only one of the part 3 code should be run depending on the number of measurements

if (measurements==1){
# This first part is when we have only one wind v. elevation measurement.
# Outputs are Uh, Ufriction, z1, z0, alpha_avg, k2

profile<-wvprofile(z1, ux1, ch)
z0<-profile[1]
Uf<-profile[2]
}else if (measurements==2){
# Part for when we have two wind v. elevation measurements.
z0<-WV2m(z1,z2,ux1,ux2)[1]
Uf<-WV2m(z1,z2,ux1,ux2)[2]
}

# Part 4
# ________________________________________
# Droplet Transport
source("4_Nozzle_Characteristics.R")
charac<-charact_cal(app_p,angle, rhosoln) 

# Calculated from previous function
DTwb<-Twb[1] # Wetbulb temperature depression, C

source ("4_Droplet_Transport_function.R")

print("Solving Straight Down Problem")
droplet_1<-droplet_transport(Tair,RH,rhow,rhos,xs0,H0,DTwb,hcm,Uf,z0,app_p,charac[1],charac[2],ddd1,"text")
print("Solving with Wind Problem")
droplet_2<-droplet_transport(Tair,RH,rhow,rhos,xs0,H0,DTwb,hcm,Uf,z0,app_p,charac[3],charac[4],ddd2,"text")
print("Solving against Wind Problem")
droplet_3<-droplet_transport(Tair,RH,rhow,rhos,xs0,H0,DTwb,hcm,Uf,z0,app_p,charac[5],charac[6],ddd3,"text")

print("Finished Solving for Droplet Transport")

# Part 5
# ________________________________________
a<-unname(pars$res)  # Calibration from step #1 (removing the stored names)

# Input from previous function
Cent<-droplet_1[2]$Xdist
Dwnd<-droplet_2[2]$Xdist
Uwnd<-droplet_3[2]$Xdist

source("5_Deposition_Calcs_function.R")
deposition<-deposition_calcs(IAR,xactive,FD,PL, NozzleSpacing, psipsipsi,rhoL, Cent,Dwnd,Uwnd, Dpmax, DDpmin,a,MMM, lambda,"text")

# Plot results
x11()
deposition$dep_plot

# Stop the clock
proc.time() - ptm  # 

