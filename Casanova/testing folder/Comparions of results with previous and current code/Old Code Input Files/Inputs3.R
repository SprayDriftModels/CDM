# Part 1
# ________________________________________
# Curve fitting function
# Average DSD fit data:
y<-c(0,0.056666667,0.216666667,0.58,1.126666667,1.866666667,3.173333333,5.33,8.686666667,12.84666667,19.47333333,29.16666667,42.18666667,58.13,75.95,93.33,99.99,100)
# Corresponding droplet size (in microns):
Dpdata<-c( 86,100,120,150,180,210,250,300,360,410,500,600,720,860,1020,1220,1460,1740)

# Part 2
# ________________________________________
# Wet Bulb Calculations
# Inputs are in sequence Dry air temperature, degrees C, Barometric pressure, mmHg abs and Percent relative humidity

#  # User Input:
Tair<-17.69 # Dry air temperature, degrees C
Patm<-760 # Barometric pressure, mmHg abs
RH<-35.65  # Percent relative humidity

# Part 3
# ________________________________________
#

# Only need to put appropriate params for the appropriate case (1 vs 2 measurements)
measurements<-1 # Number of wind vs. height sets of measurements

if (measurements==1){
  # This first part is when we have only one wind v. elevation measurement.
  # Inputs are crop height (inches), wind elevation measurement (feet), and wind speed (mph)/height (feet)
  # User Input:
  ch<-4 # crop height, inches
  z1<-6.6 # elevation of wind velocity in ft
  ux1<-12.8 # mph wind velocity at elevation

}else if (measurements==2){
  # Part for when we have two wind v. elevation measurements.
  # User Input: Two wind measurements (elevationin feet, speed in mph):
  z1<-10
  z2<-1.66667
  ux1<-12.8
  ux2<-9.44
}

# Part 4
# ________________________________________
# Droplet Transport
# # User Inputs:

rhow<-1 # Density of pure water in droplet
rhos<-2.01594  # Density of dissolved solids in droplet, g/cc
xs0<-0.0198  # mass fraction total dissolved solids in solution

# Mix density (rows 25 to 42)
rhosoln<-1008.7 # in kg/m^3  # New input (need to be added to GUI)
#
H0<-20 # Height of nozzle above ground , inches
hcm<-0.645 # Canopy height in cms
app_p<-50 # Nozzle pressure, psi

angle<-110
p<-c(20,30,40,50,60,70,80)
NF<-c(0.28,0.35, 0.4,0.45, 0.49,0.53,0.57)

# ddd parameters
ddd1<-c(40,40,40,1.05,1.05,1.05,1.05,1.05,1.05,1.05,1.05,1.02,1.02,1.02,1.02,1.02,1.02,1.04,1.04,1.04,20,10,10)
ddd2<-c(40,40,40,1.05,1.05,1.05,1.05,1.05,1.05,1.05,1.05,1.02,1.02,1.02,1.02,1.02,1.02,1.04,1.04,1.04,20,10,10)
ddd3<-c(40,40,40,1.05,1.05,1.05,1.05,1.05,1.05,1.05,1.05,1.02,1.02,1.02,1.02,1.02,1.02,1.04,1.04,1.04,20,10,10)



# Part 5
# ________________________________________
# User Inputs:
IAR<-0.6088 #Intended Application Rate for Dicamba, lb/acre
xactive<-0.0119 #Dicamba conc in tank solution, wtfraction
FD<-240.16 # Downwind field depth, ft
PL<-787.4 # Crosswind field width, ft
NozzleSpacing<-20 # Space between nozzles on Boom, inches
psipsipsi<-10.7 # Horizontal variation in wind direction around mean direction, 1 stdev, in degrees.
rhoL<-rhosoln/1000 # Density of sprayed solution, grams/cc
Dpmax<-1350
DDpmin<-18

# Integration input parameters
MMM<-500 # Original value
lambda<-2 # Original value; Controls resolution of deposition calculations; higher numbers increase accuracy


