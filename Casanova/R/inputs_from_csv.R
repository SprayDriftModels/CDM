# This file needs to handle unit conversion too

# NEED TO REMOVE UNIT REFERENCES
# Part 1
# ________________________________________
# Average DSD fit data:

# Average DSD data; this averages the data for each row
y_temp<-rowMeans(DSDData[,2:length(DSDData)])

## Determine where to draw the cut-off (begin with first value over zero and end with first value that reaches 100)
i_firsty <- max(min(which(y_temp > 0))-1,1)
i_lasty <- max(which(y_temp < 100)) + 1
y<-y_temp[i_firsty:i_lasty]
Dpdata<-unname(DSDData$Droplet_Size_microns[i_firsty:i_lasty]) # Corresponding droplet size (in microns):


# Part 2
# ________________________________________
# Inputs are in sequence Dry air temperature, degrees C, Barometric pressure, mmHg abs and Percent relative humidity

#  # User Input:
Tair<-paramsData[which(paramsData$ID=='Tair'),][i+2] # Dry air temperature, degrees C
Patm<-paramsData[which(paramsData$ID=='Patm'),][i+2] # Barometric pressure, mmHg abs
RH<-paramsData[which(paramsData$ID=='RH'),][i+2]  # Percent relative humidity

# Part 3
# ________________________________________
#

# Only need to put appropriate params for the appropriate case (1 vs 2 measurements)
measurements<-paramsData[which(paramsData$ID=='measurements'),][i+2] # Number of wind vs. height sets of measurements

if (measurements==1){
  # This first part is when we have only one wind v. elevation measurement.
  # Inputs are crop height (inches), wind elevation measurement (feet), and wind speed (mph)/height (feet)
  # User Input:
  ch<-paramsData[which(paramsData$ID=='ch'),][i+2] # crop height, inches
  z1<-paramsData[which(paramsData$ID=='z1'),][i+2] # elevation of wind velocity in ft
  ux1<-paramsData[which(paramsData$ID=='ux1'),][i+2] # mph wind velocity at elevation

}else if (measurements==2){
  # Part for when we have two wind v. elevation measurements.
  # User Input: Two wind measurements (elevationin feet, speed in mph):
  z1<-paramsData[which(paramsData$ID=='z1'),][i+2]
  z2<-paramsData[which(paramsData$ID=='z2'),][i+2]
  ux1<-paramsData[which(paramsData$ID=='ux1'),][i+2]
  ux2<-paramsData[which(paramsData$ID=='ux2'),][i+2]
}

# Part 4
# ________________________________________
# Droplet Transport
# # User Inputs:

rhow<-paramsData[which(paramsData$ID=='rhow'),][i+2] # Density of pure water in droplet
rhos<-paramsData[which(paramsData$ID=='rhows'),][i+2]  # Density of dissolved solids in droplet, g/cc
xs0<-paramsData[which(paramsData$ID=='xs0'),][i+2]  # mass fraction total dissolved solids in solution

# Mix density (rows 25 to 42)
rhosoln<-paramsData[which(paramsData$ID=='rhosoln'),][i+2] # in kg/m^3  # New input (need to be added to GUI)
#
H0<-paramsData[which(paramsData$ID=='H0'),][i+2] # Height of nozzle above ground , inches
hcm<-paramsData[which(paramsData$ID=='hcm'),][i+2] # Canopy height in cms
app_p<-paramsData[which(paramsData$ID=='app_p'),][i+2] # Nozzle pressure, psi

angle<-paramsData[which(paramsData$ID=='angle'),][i+2]

# ddd parameters
ddd1 <- DDDparamsData$ddd1
ddd2 <- DDDparamsData$ddd2
ddd3 <- DDDparamsData$ddd3


# Part 5
# ________________________________________
# User Inputs:
IAR<-paramsData[which(paramsData$ID=='IAR'),][i+2] #Intended Application Rate for Dicamba, lb/acre
xactive<-paramsData[which(paramsData$ID=='xactive'),][i+2] #Dicamba conc in tank solution, wtfraction
FD<-paramsData[which(paramsData$ID=='FD'),][i+2] # Downwind field depth, ft
PL<-paramsData[which(paramsData$ID=='PL'),][i+2] # Crosswind field width, ft
NozzleSpacing<-paramsData[which(paramsData$ID=='NozzleSpacing'),][i+2] # Space between nozzles on Boom, inches
psipsipsi<-paramsData[which(paramsData$ID=='psipsipsi'),][i+2] # Horizontal variation in wind direction around mean direction, 1 stdev, in degrees.
rhoL<-rhosoln/1000 # Density of sprayed solution, grams/cc
Dpmax<-paramsData[which(paramsData$ID=='Dpmax'),][i+2]
DDpmin<-paramsData[which(paramsData$ID=='Dpmin'),][i+2]

# Integration input parameters
MMM<-paramsData[which(paramsData$ID=='MMM'),][i+2] # Original value
lambda<-paramsData[which(paramsData$ID=='lambda'),][i+2] # Original value; Controls resolution of deposition calculations; higher numbers increase accuracy

