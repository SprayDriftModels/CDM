#' Input from csv and converts units as needed
#'
#' @param DSDData the raw DSDData
#' @param paramsData the raw paramsData
#' @param DDDparamsData  the raw DDDparamsData
#' @param paramsID the ID for the parameters
#' @param paramsUnits the type of the parameters
#' @param WTFile is the file containing the Wind/Temperature parameters if more than one measurements are provided
#'
#' @return a list containing all input data
#' @export
#'
#' @examples
inputs_from_csv <- function(DSDData,
                            paramsData,
                            DDDparamsData,
                            paramsID,
                            paramsUnits,
                            paramsWT){

  # Comments in code next to each input parameter provide descriptions of units used in computation modules
  # This function at the end converts units to the units used in computation modules





  # Part 1
  # ________________________________________
  # Average DSD fit data:
  # Average DSD data; this averages the data for each row
  y_temp<-rowMeans(DSDData[,2:length(DSDData)])

  # Make y_temp cumulative
  for (i in 2:length(y_temp)){
    y_temp[i]<-y_temp[i]+y_temp[i-1]
  }

  ## Determine where to draw the cut-off (begin with first value over zero and end with first value that reaches 100)
  i_firsty <- max(min(which(y_temp > 0)),1)
  i_lasty <- max(which(y_temp < 100)) + 1
  y<-y_temp[i_firsty:i_lasty]
  y<-c(0,y)
  Dpdata<-unname(DSDData$Droplet_Size_microns[i_firsty:i_lasty]) # Corresponding droplet size, units used in computation module: microns
  Dpdata<-c(0,Dpdata)

  # Change the first element of the Dpdata vector
  Dpdata[1]<-Dpdata[2]-(Dpdata[3]-Dpdata[2])/(y[3]-y[2])*y[2]

  # Change the last element of the Dpdata vector
  Dpdata[length(Dpdata)]<-Dpdata[length(Dpdata)-1]+
    (Dpdata[length(Dpdata)-1]-Dpdata[length(Dpdata)-2])/(y[length(Dpdata)-1]-y[length(Dpdata)-2])*(100-y[length(Dpdata)-1])

  # browser()
  # Part 2
  # ________________________________________

  #  # User Input:
  Tair<-as.double(paramsData[which(paramsData$Type=='Tair'),][paramsID+3]) # Dry air temperature, units used in computation module: C
  Patm<-as.double(paramsData[which(paramsData$Type=='Patm'),][paramsID+3]) # Barometric pressure, units used in computation module: mmHg abs
  RH<-as.double(paramsData[which(paramsData$Type=='RH'),][paramsID+3])  # Percent relative humidity, units used in computation module: %

  # Part 3
  # ________________________________________
  #

  # Only need to put appropriate params for the appropriate case (1 vs 2 measurements)
  # measurements<-as.double(paramsData[which(paramsData$Type=='measurements'),][paramsID+3]) # Number of wind vs. height sets of measurements
  measurements <- paramsWT %>% select(c(1)) %>% na.omit() %>% nrow() %>% as.integer()
  if (measurements == 1){
    # This first part is when we have only one wind v. elevation measurement.
    ch <- as.double(paramsData[which(paramsData$Type == 'ch'), ][paramsID + 3]) # crop height, units used in computation module: inches
    z1 <- as.double(paramsWT %>% select(starts_with("zw")) %>% deframe()) # elevation of wind velocity, units used in computation module: ft
    ux1 <- as.double(paramsWT %>% select(starts_with("u")) %>% deframe()) # wind velocity at elevation, units used in computation module: mph
    #z2<-NULL
    #ux2<-NULL
    paramsWT <- NULL #***SFR why is this here?

  } else if (measurements > 1){
    # # In this case the Wind/Temperature file is needed:
    # paramsWT<-NULL
    # paramsWT <- tryCatch({
    #   read_csv(paramsWTFile,col_types='dddd')
    # },
    # error=function(e){
    #   print("Could not read wind/temperature File")
    # }
    # )

    # Part for when we have two wind v. elevation measurements.
    #z1<-as.double(paramsData[which(paramsData$Type=='z1'),][paramsID+3]) # elevation 1, units used in computation module: feet
    #z2<-as.double(paramsData[which(paramsData$Type=='z2'),][paramsID+3]) # elevation 2, units used in computation module: feet
    #ux1<-as.double(paramsData[which(paramsData$Type=='ux1'),][paramsID+3]) # wind speed 1, units used in computation module: mph
    #ux2<-as.double(paramsData[which(paramsData$Type=='ux2'),][paramsID+3]) # wind speed 2, units used in computation module: mph
    z1 <- NULL
    #z2<-NULL
    ux1 <- NULL
    #ux2<-NULL
    ch <- as.double(paramsData[which(paramsData$Type == 'ch'), ][paramsID + 3]) # crop height, units used in computation module: inches
  }

  # Part 4
  # ________________________________________
  # Droplet Transport

  rhow<-as.double(paramsData[which(paramsData$Type=='rhow'),][paramsID+3]) # Density of pure water in droplet, units used in computation module: g/cc
  rhos<-as.double(paramsData[which(paramsData$Type=='rhos'),][paramsID+3])  # Density of dissolved solids in droplet, units used in computation module: g/cc
  xs0<-as.double(paramsData[which(paramsData$Type=='xs0'),][paramsID+3])  # mass fraction total dissolved solids in solution

  # Mix density (rows 25 to 42)
  rhosoln<-as.double(paramsData[which(paramsData$Type=='rhosoln'),][paramsID+3]) # in units used in computation module: kg/m^3  # New input (need to be added to GUI)

  #
  H0<-as.double(paramsData[which(paramsData$Type=='H0'),][paramsID+3]) # Height of nozzle above ground , units used in computation module: inches
  hcm<-as.double(paramsData[which(paramsData$Type=='hcm'),][paramsID+3]) # Canopy height in, units used in computation module: cm
  app_p<-as.double(paramsData[which(paramsData$Type=='app_p'),][paramsID+3]) # Nozzle pressure, units used in computation module: psi

  angle<-as.double(paramsData[which(paramsData$Type=='angle'),][paramsID+3]) # angle, units used in computation module: degrees

  # ddd parameters
  ddd1 <- DDDparamsData$ddd1
  ddd2 <- DDDparamsData$ddd2
  ddd3 <- DDDparamsData$ddd3


  # Part 5
  # ________________________________________
  # User Inputs:
  IAR<-as.double(paramsData[which(paramsData$Type=='IAR'),][paramsID+3]) #Intended Application Rate for Dicamba, units used in computation module: lb/acre
  xactive<-as.double(paramsData[which(paramsData$Type=='xactive'),][paramsID+3]) #Dicamba concentration in tank solution, wtfraction
  FD<-as.double(paramsData[which(paramsData$Type=='FD'),][paramsID+3]) # Downwind field depth, units used in computation module: ft
  PL<-as.double(paramsData[which(paramsData$Type=='PL'),][paramsID+3]) # Crosswind field width, units used in computation module: ft
  NozzleSpacing<-as.double(paramsData[which(paramsData$Type=='NozzleSpacing'),][paramsID+3]) # Space between nozzles on Boom, units used in computation module: inches
  method<-as.double(paramsData[which(paramsData$Type=='psipsipsi_method'),][paramsID+3]) # Method to calculate psipsipsi used when more than 1 measurements are provided
  psipsipsi<-as.double(paramsData[which(paramsData$Type=='psipsipsi'),][paramsID+3]) # Horizontal variation in wind direction around mean direction, 1 stdev, units used in computation module: in degrees.
  rhoL<-rhosoln/1000 # Density of sprayed solution, units used in computation module: grams/cc
  Dpmax<-max(Dpdata)
  DDpmin<-min(Dpdata)

  # Integration input parameters
  MMM<-as.double(paramsData[which(paramsData$Type=='MMM'),][paramsID+3]) # Original value
  lambda<-as.double(paramsData[which(paramsData$Type=='lambda'),][paramsID+3]) # Original value; Controls resolution of deposition calculations; higher numbers increase accuracy

  # browser()

  # As provided list of properties:
  input_props <- list(
    y = y,
    Dpdata = Dpdata,
    Tair = Tair,
    Patm = Patm,
    RH = RH,
    measurements = measurements,
    ch = ch,
    z1 = z1,
    ux1 = ux1,
    rhow = rhow,
    rhos = rhos,
    xs0 = xs0,
    rhosoln = rhosoln,
    H0 = H0,
    hcm = hcm,
    app_p = app_p,
    angle = angle,
    ddd1 = ddd1,
    ddd2 = ddd2,
    ddd3 = ddd3,
    IAR = IAR,
    xactive = xactive,
    FD = FD,
    PL = PL,
    NozzleSpacing = NozzleSpacing,
    psipsipsi = psipsipsi,
    rhoL = rhoL,
    Dpmax = Dpmax,
    DDpmin = DDpmin,
    MMM = MMM,
    lambda = lambda,
    paramsWT = paramsWT,
    method = method
  )

  # Convert input units to units used in the computation module
  if (paramsUnits=='English') {
    Tair<-(Tair-32)*5/9 # Computation module uses degrees C
    paramsWT[[4]]<-(paramsWT[[4]]-32)*5/9  # Computation module uses degrees C
    rhow<-rhow/62.428 # Computation module uses g/cc
    rhos<-rhos/62.428 # Computation module uses g/cc
    rhosoln<-rhosoln/0.062428 # Computation module uses kg/m3
    rhoL<-rhoL/0.062428   # Computation module uses g/cc
    hcm<-hcm*2.54 # Computation module uses cm
  } else {
    ch<-ch/2.54  # Computation module uses in
    z1<-z1*3.28084  # Computation module uses ft
    ux1<-ux1*2.23694     # Computation model used mph
    paramsWT[[1]]<-paramsWT[[1]]*3.28084  # Computation module uses ft
    paramsWT[[2]]<-paramsWT[[2]]*2.23694  # Computation module used mph
    paramsWT[[3]]<-paramsWT[[3]]*3.28084  # Computation module uses ft
    H0<-H0/2.54  # Computation module uses in
    app_p<-app_p*0.145038 # Computation module uses psi
    IAR<-IAR*2.20462/2.47105 # Computation module uses lb/acre
    FD<-FD*3.28084  # Computation module uses ft
    PL<-PL*3.28084   # Computation module uses ft
    NozzleSpacing<-NozzleSpacing/2.54   # Computation module uses in
  }

  # Converted list of properties to the units used in computation modules
  input_props_comp <- list(
    y = y,
    Dpdata = Dpdata,
    Tair = Tair,
    Patm = Patm,
    RH = RH,
    measurements = measurements,
    ch = ch,
    z1 = z1,
    ux1 = ux1,
    rhow = rhow,
    rhos = rhos,
    xs0 = xs0,
    rhosoln = rhosoln,
    H0 = H0,
    hcm = hcm,
    app_p = app_p,
    angle = angle,
    ddd1 = ddd1,
    ddd2 = ddd2,
    ddd3 = ddd3,
    IAR = IAR,
    xactive = xactive,
    FD = FD,
    PL = PL,
    NozzleSpacing = NozzleSpacing,
    psipsipsi = psipsipsi,
    rhoL = rhoL,
    Dpmax = Dpmax,
    DDpmin = DDpmin,
    MMM = MMM,
    lambda = lambda,
    paramsWT = paramsWT,
    method = method
  )

  return(
    list(input_props=input_props, input_props_comp=input_props_comp)
  )


}
