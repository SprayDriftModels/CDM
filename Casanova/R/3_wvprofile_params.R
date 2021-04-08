#' Function when 1 wind vs. height measurements are available
#'
#' @param z1 1st Elevation wind speed (ft):
#' @param ux1 1st wind speed (mph):
#' @param ch Canopy_height (in):
#'
#' @return Friction height, cm (z0) and Friction velocity, cm/sec (uf)
#' @export
#'
#' @examples
wvprofile <- function(z1, ux1, ch){

  ch<-ch*0.0254 # convert crop height in to m
  zcm <- z1*12*2.54
  Vcms <- ux1*5280*12*2.54/3600

  z0 <- (0.00340738473+0.1244537*ch)*100 # in cm
  Uf <- Vcms*0.41/log(zcm/z0) # in cm/s

  return(c(z0, Uf))
}


#' Function when 2 wind vs. height measurements are available
#'
#' @param z1 elevation of wind velocity in ft
#' @param z2  elevation of wind velocity in ft
#' @param ux1  mph wind velocity at elevation
#' @param ux2 mph wind velocity at elevation
#'
#' @return
#' @export
#'
#' @examples
WV2m <- function(z1, z2, ux1, ux2){



  slope <- (44.704*ux1-44.704*ux2)/(log(30.48*z1)-log(30.48*z2))
  Uf <- slope*0.4 # ( in cm/s)
  intercept <- 44.704*ux1-slope*log(30.48*z1)

  z0 <- exp(-intercept*0.4/Uf)

  return(c(z0, Uf, psipsipsi))
}



#' Function when more than 1 wind vs. height measurements are available
#'
#' @param paramsWT wind speed, temperature vs. elevation
#' @param ch crop height
#'
#' @return
#' @export
#'
#' @examples
wvprofilem <- function(paramsWT,method, ch){

  # Hardcode psipsipsi vs. Ri function
  Ri<-c(-0.86, -.615, -0.235, -0.024, 0.094, 0.236, 0.339)
  psipsipsi_I<-c(22.5, 20, 15, 10, 5.63, 2.88, 2.00)
  fun_psipsipsi<-approxfun(x=Ri,y=psipsipsi_I, method='linear')
  ch<-ch*0.0254 # convert crop height in to m

  z0 <- (0.00340738473+0.1244537*ch)*100 # in cm

  # Read values and remove NA created by different length of V and temp vectors
  zcm <- paramsWT[[1]]*12*2.54
  zcm<-zcm[!is.na(zcm)]
  Vcms <- paramsWT[[2]]*5280*12*2.54/3600
  Vcms<-Vcms[!is.na(Vcms)]
  ztcm <- paramsWT[[3]]*12*2.54
  ztcm<-ztcm[!is.na(ztcm)]
  temp <- paramsWT[[4]]
  temp<-temp[!is.na(temp)]

  u_function<-function(z){
    z*sum(Vcms)/sum(log(zcm/z0))
  }
  Uf<-0.41*sum(Vcms)/sum(log(zcm/z0))
  zz<-log(ztcm/z0)
  N<-length(temp[!is.na(temp)])

  intercept <- (sum(temp)*sum(zz^2)-sum(zz)*sum(temp*zz))/(N*sum(zz^2)-(sum(zz)^2))
  slope <-(N*sum(temp*zz)-sum(zz)*sum(temp))/(N*sum(zz^2)-(sum(zz))^2)
  tempfunction<-function(z){
    intercept+slope*log(z/z0)
  }

  # Calculate Richardson number (Ri)

  Ri<-981/((tempfunction(30.48)+tempfunction(914.4))/2+273.15)*((tempfunction(30.48)-tempfunction(914.4))/(30.48-914.4))/((u_function(30.48)-u_function(914.4))/(30.48-914.4))^2

  if (method==1){
    psipsipsi<-fun_psipsipsi(Ri)
  }
  else if (method!=1){
    psipsipsi<-0.524*ch-69.398*Ri*sign(-Ri)
  }
  return(c(z0, Uf, psipsipsi)) # Computational units are z0 cm, uf cm/s
}
