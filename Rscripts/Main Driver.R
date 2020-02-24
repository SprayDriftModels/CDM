# Main Driver
library(rstudioapi)

# Clear all memory
rm(list = ls())

# Remove all figures
graphics.off()

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
source("./Unaltered/1_psd_function.R")

# The following contains the fitted parameters of the drop size distribution model
pars<-psd(y,Dpdata)


# Part 2
# ________________________________________
# Wet Bulb Calculations
source("2_wet_bulb_function.R")

# The following contains the wet bulb temperature
# Inputs are in sequence Dry air temperature, ?C, Barometric pressure, mmHg abs and Percent relative humidity
# Outputs are: DTwb,Twb

#  # User Input:
Tair<-17.689 # Dry air temperature, ?C
Patm<-760 # Barometric pressure, mmHg abs
RH<-35.65  # Percent relative humidity

Twb<-wet_bulb(Tair,Patm,RH)  


# Part 3
# ________________________________________
# 
source("3_wvprofile_params.R")
source("3_WV2measurements.R")

# Only one of the part 3 code should be run depending on the number of measurements

measurements<-2 # Number of wind vs. height sets of measurements

if (measurements==1){
# This first part is when we have only one wind v. elevation measurement.
# Inputs are lambda (fraction vegetation), canopy height (inches), boom height (inches), and wind speed (mph)/height (feet)
# Outputs are Uh, Ufriction, z1, z0, alpha_avg, k2
# User Input:
lambda<-0.08  # Project area ratio of vegetation in wind direction per area of ground surfaca
hcin<-4 # canopy height, inches
h0in<-20 #boom height above canopy, inches
zft<-6.6 # elevation of wind velocity in ft
Vmph<-12.8 # mph wind velocity at elevation

profile<-wvprofile(lambda,hcin,h0in,zft,Vmph)
z0<-profile[4]
Uf<-profile[2]
}else if (measurements==2){
#### Part for when we have two wind v. elevation measurements.
# User Input: Two wind measurements (elevationin feet, speed in mph):
z1<-6.6
z2<-1.66667
ux1<-13.5
ux2<-9.44
z0<-WV2m(z1,z2,ux1,ux2)[1]
Uf<-WV2m(z1,z2,ux1,ux2)[2]
}

# Part 4
# ________________________________________
# Droplet Transport
source("4_Nozzle_Characteristics.R")
# User Input:
# # User Inputs:
Tair<-17.689  # Ambient Air temperature, C
RH<-35.65     # Relative Humidity of Ambient Air, %
# 
rhow<-1 # Density of pure water in droplet
rhos<-2.01594  # Density of dissolved solids in droplet, g/cc
xs0<-0.019369  # mass fraction total dissolved solids in solution
# 
H0<-24 # Height of nozzle above ground , inches
hcm<-0 # Canopy height in cms
app_p<-63 # Nozzle pressure, psi

angle<-110 
p<-c(20,30,40,50,60,70,80)
NF<-c(0.28,0.35, 0.4,0.45, 0.49,0.53,0.57)
charac<-charact_cal(app_p,angle, p,NF)

# Calculated from previous function
DTwb<-Twb[1] # Wetbulb temperature depression, C

# Below is the exact values used in MathCAD code:
ddd1<-c(40,40,40,1.05,1.05,1.05,1.05,1.05,1.05,1.05,1.05,1.02,1.02,1.02,1.02,1.02,1.02,1.04,1.04,1.04,20,10,10)
ddd2<-c(40,40,40,1.05,1.05,1.05,1.05,1.05,1.05,1.05,1.05,1.02,1.02,1.02,1.02,1.02,1.02,1.04,1.04,1.04,20,10,10)
ddd3<-c(40,40,40,1.05,1.05,1.05,1.05,1.05,1.05,1.05,1.05,1.02,1.02,1.02,1.02,1.02,1.02,1.04,1.04,1.04,20,10,10)

source ("./Unaltered/4_Droplet_Transport_function.R")
# Inputs are Tair,RH,rhow,rhos,xs0,H0,DTwb,hcm,Uf,z0,Pn,Vz0,Vx0
# # Wind horozontal velocity parameters # These are estimated from step 3; here trying other values for debugging
#Uf<-43.66 # Friction velocity parameter, cm/sec
#z0<-1.063 # Friction height, cm

#droplet_1<-droplet_transport(17.689,35.65,1,2.01594,0.019369,24,7.696,0,Uf,z0,app_p,-2352.6,-1751.5,ddd1) # Debugging run

print("Solving Straight Down Problem")
droplet_1<-droplet_transport(Tair,RH,rhow,rhos,xs0,H0,DTwb,hcm,Uf,z0,app_p,charac[1],charac[2],ddd1)
print("Solving with Wind Problem")
droplet_2<-droplet_transport(Tair,RH,rhow,rhos,xs0,H0,DTwb,hcm,Uf,z0,app_p,charac[3],charac[4],ddd2)
print("Solving against Wind Problem")
droplet_3<-droplet_transport(Tair,RH,rhow,rhos,xs0,H0,DTwb,hcm,Uf,z0,app_p,charac[5],charac[6],ddd3)

print("Finished Solving for Droplet Transport")

# Part 5
# ________________________________________
# User Inputs:
IAR<-0.4996 #Intended Application Rate for Dicamba, lb/acre
xactive<-0.003884 #Dicamba conc in tank solution, wtfraction
FD<-240.16 # Downwind field depth, ft
PL<-787.4 # Crosswind field width, ft
NozzleSpacing<-20 # Space between nozzles on Boom, inches
psipsipsi<-10.7 # Horizontal variation in wind direction around mean direction, 1 stdev, in degrees.
rhoL<-1.0084 # Density of sprayed solution, grams/cc
Dpmax<-1350
DDpmin<-18
a<-unname(pars)  # Calibration from step #1 (removing the stored names)

# Integration input parameters
MMM<-500 # Original value

#***[SFR] Distinguishining from previous lambda
lambda_res<-3 # Original value; Controls resolution of deposition calculations; higher numbers increase accuracy

  
# Input from previous function
Cent<-droplet_1[2]$Xdist
Dwnd<-droplet_2[2]$Xdist
Uwnd<-droplet_3[2]$Xdist

# For debugging purposes
# View(cbind(Cent,Dwnd,Uwnd))

# It works with the full input from below
#Cent=c(6074.3077395014800,3008.2711710000700,1702.2565938512800,158.8870043040930,111.5875319864090,80.5230949159303,58.3746456679478,40.9386212100869,27.7852429177426,20.6425385026667,15.8727589758146,12.4100870734410,9.7762212414321,3.3389046227334,0.5308583135306,0.1405814853959,0.0611040296598,0.0320750980311,0.0185969534580,0.0114569125157,0.0073482842755,0.0048487954490,0.0032676033206)
#Dwnd=c(6109.0004010223400,3038.2405125546000,1728.7395743989300,159.8149880902540,112.6235491719470,81.7560172281201,59.9877729510145,43.6458353627741,30.4196919274483,22.9969411330500,18.1125086436096,14.6008429009690,11.9512268187871,5.5734905904742,2.5350482785354,1.7507450326249,1.5263877993506,1.4163252068338,1.3513103140577,1.3095967117924,1.2815972828816,1.2622626663387,1.2486430939340)
#Uwnd=c(6108.9424598105100,3038.1452360895400,1728.5991924404000,159.5741959274380,112.3063575445070,81.3549649606991,59.4959622726660,43.0576746069967,29.7258346550706,22.1908770208012,17.1897045643011,13.5564926167946,10.7806116323463,3.8148881046676,0.0345609884263,-0.8762399709143,-1.0539917896701,-1.1227289328319,-1.1567684338184,-1.1758027715635,-1.1872409303725,-1.1944459195259,-1.1991356849360)


source("./Unaltered/5_Deposition_Calcs_function.R")
#***[SFR] Distinguishining from previous lambda
deposition<-deposition_calcs(IAR,xactive,FD,PL, NozzleSpacing, psipsipsi,rhoL, Cent,Dwnd,Uwnd, Dpmax, DDpmin,a,MMM, lambda_res)

# Stop the clock
proc.time() - ptm  # 


# Part 6
# ________________________________________
# Sample Plots

