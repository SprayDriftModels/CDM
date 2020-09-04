# Function when 1 wind vs. height measurements are available
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

  #######################
  # Example Overide; different equations:
  z0 <- (0.00340738473+0.1244537*ch)*100 # in cm
  Uf <- Vcms*0.41/log(zcm/z0) # in cm/s
  #######################

  return(c(z0, Uf))
}


# Function when 2 wind vs. height measurements are available
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

  return(c(z0, Uf))
}
