#' Read inputs from the csv files and converts units as needed
#'
#' @param DSDData the raw DSDData read from .csv file
#' @param paramsData the raw paramsData read from .csv file
#' @param DDDparamsData  the raw DDDparamsData read from .csv file
#' @param paramsID the ID for the parameters
#' @param paramsType the type of the parameters
#'
#' @return a list containing all input data
#' @export
#'
#' @examples
inputs_from_csv <- function(DSDData,
                            paramsData,
                            DDDparamsData,
                            paramsID,
                            paramsType){

  # Comments in code provide descriptions of units used in computation modules
  # Part 1
  # ________________________________________
  # Average DSD fit data:
  #browser()

  # Average DSD data; this averages the data for each row
  y_temp<-rowMeans(DSDData[,2:length(DSDData)])

  ## Determine where to draw the cut-off (begin with first value over zero and end with first value that reaches 100)
  i_firsty <- max(min(which(y_temp > 0))-1,1)
  i_lasty <- max(which(y_temp < 100)) + 1
  y<-y_temp[i_firsty:i_lasty]
  Dpdata<-unname(DSDData$Droplet_Size_microns[i_firsty:i_lasty]) # Corresponding droplet size, microns

  # Part 2
  # ________________________________________

  #  # User Input:
  Tair<-as.double(paramsData[which(paramsData$ID=='Tair'),][paramsID+3]) # Dry air temperature, C
  Patm<-as.double(paramsData[which(paramsData$ID=='Patm'),][paramsID+3]) # Barometric pressure, mmHg abs
  RH<-as.double(paramsData[which(paramsData$ID=='RH'),][paramsID+3])  # Percent relative humidity, %

  #browser()
  # Part 3
  # ________________________________________
  #

  # Only need to put appropriate params for the appropriate case (1 vs 2 measurements)
  measurements<-as.double(paramsData[which(paramsData$ID=='measurements'),][paramsID+3]) # Number of wind vs. height sets of measurements
  if (measurements==1){
    # This first part is when we have only one wind v. elevation measurement.
    ch<-as.double(paramsData[which(paramsData$ID=='ch'),][paramsID+3]) # crop height, inches
    z1<-as.double(paramsData[which(paramsData$ID=='z1'),][paramsID+3]) # elevation of wind velocity, ft
    ux1<-as.double(paramsData[which(paramsData$ID=='ux1'),][paramsID+3]) # wind velocity at elevation, mph
    z2<-NULL
    ux2<-NULL

  }else if (measurements==2){
    # Part for when we have two wind v. elevation measurements.
    z1<-as.double(paramsData[which(paramsData$ID=='z1'),][paramsID+3]) # elevation 1, feet
    z2<-as.double(paramsData[which(paramsData$ID=='z2'),][paramsID+3]) # elevation 2, feet
    ux1<-as.double(paramsData[which(paramsData$ID=='ux1'),][paramsID+3]) # wind speed 1, mph
    ux2<-as.double(paramsData[which(paramsData$ID=='ux2'),][paramsID+3]) # wind speed 2, mph
    ch<-NULL
  }

  # Part 4
  # ________________________________________
  # Droplet Transport

  rhow<-as.double(paramsData[which(paramsData$ID=='rhow'),][paramsID+3]) # Density of pure water in droplet, g/cc
  rhos<-as.double(paramsData[which(paramsData$ID=='rhos'),][paramsID+3])  # Density of dissolved solids in droplet, g/cc
  xs0<-as.double(paramsData[which(paramsData$ID=='xs0'),][paramsID+3])  # mass fraction total dissolved solids in solution

  # Mix density (rows 25 to 42)
  rhosoln<-as.double(paramsData[which(paramsData$ID=='rhosoln'),][paramsID+3]) # in kg/m^3  # New input (need to be added to GUI)

  #
  H0<-as.double(paramsData[which(paramsData$ID=='H0'),][paramsID+3]) # Height of nozzle above ground , inches
  hcm<-as.double(paramsData[which(paramsData$ID=='hcm'),][paramsID+3]) # Canopy height in, cm
  app_p<-as.double(paramsData[which(paramsData$ID=='app_p'),][paramsID+3]) # Nozzle pressure, psi

  angle<-as.double(paramsData[which(paramsData$ID=='angle'),][paramsID+3]) # angle, degrees

  # ddd parameters
  ddd1 <- DDDparamsData$ddd1
  ddd2 <- DDDparamsData$ddd2
  ddd3 <- DDDparamsData$ddd3

  # browser()

  # Part 5
  # ________________________________________
  # User Inputs:
  IAR<-as.double(paramsData[which(paramsData$ID=='IAR'),][paramsID+3]) #Intended Application Rate for Dicamba, lb/acre
  xactive<-as.double(paramsData[which(paramsData$ID=='xactive'),][paramsID+3]) #Dicamba conc in tank solution, wtfraction
  FD<-as.double(paramsData[which(paramsData$ID=='FD'),][paramsID+3]) # Downwind field depth, ft
  PL<-as.double(paramsData[which(paramsData$ID=='PL'),][paramsID+3]) # Crosswind field width, ft
  NozzleSpacing<-as.double(paramsData[which(paramsData$ID=='NozzleSpacing'),][paramsID+3]) # Space between nozzles on Boom, inches
  psipsipsi<-as.double(paramsData[which(paramsData$ID=='psipsipsi'),][paramsID+3]) # Horizontal variation in wind direction around mean direction, 1 stdev, in degrees.
  rhoL<-rhosoln/1000 # Density of sprayed solution, grams/cc
  Dpmax<-as.double(paramsData[which(paramsData$ID=='Dpmax'),][paramsID+3])
  DDpmin<-as.double(paramsData[which(paramsData$ID=='Ddpmin'),][paramsID+3])

  # Integration input parameters
  MMM<-as.double(paramsData[which(paramsData$ID=='MMM'),][paramsID+3]) # Original value
  lambda<-as.double(paramsData[which(paramsData$ID=='lambda'),][paramsID+3]) # Original value; Controls resolution of deposition calculations; higher numbers increase accuracy

  #browser()

  # Convert input units to units used in the computation module
  if (paramsType=='English')
    {
    Tair<-(Tair-32)*5/9 # Computation module uses degrees C
    rhow<-rhow/62.428 # Computation module uses g/cc
    rhos<-rhos/62.428 # Computation module uses g/cc
    rhosoln<-rhosoln/0.062428 # Computation module uses kg/m3
    rhoL<-rhoL/0.062428   # Computation module uses g/cc
    hcm<-hcm*2.54 # Computation module uses cm

  }
  else {
    ch<-ch/2.54  # Computation module uses in
    z1<-z1*3.28  # Computation module uses ft
    ux1<-ux1*2.23     # Computation model used mph
    z2<-z2*3.28  # Computation module uses ft
    ux2<-ux2*2.23     # Computation model used mph
    H0<-H0/2.54  # Computation module uses in
    app_p<-app_p*0.145038 # Computation module uses psi
    IAR<-IAR*2.20/2.47 # Computation module uses lb/acre
    FD<-FD*3.28  # Computation module uses ft
    PL<-PL*3.28   # Computation module uses ft
    NozzleSpacing<-NozzleSpacing/2.54   # Computation module uses in

  }


  # NEED TO COE THE COVERSION FROM METRIC

  return(
    list(  y,  Dpdata,
           Tair,  Patm,  RH,
           measurements,
           ch,z1,ux1, z2, ux2,
           rhow,  rhos,  xs0,  rhosoln,
           H0,  hcm,  app_p,  angle,
           ddd1,  ddd2,  ddd3,
           IAR,   xactive, FD, PL,
           NozzleSpacing,  psipsipsi,
           rhoL,  Dpmax, DDpmin,
           MMM,  lambda)
  )


}
