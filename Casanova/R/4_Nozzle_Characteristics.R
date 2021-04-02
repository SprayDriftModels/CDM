
#' Calculate three velocity components
#'
#' @param app_p Nozzle Pressure
#' @param angle Nozzle Angle
#' @param rhosoln Mix Density
#'
#' @return
#' @export
#'
#' @examples
charact_cal<-function(app_p, angle, rhosoln){

  app_p_pa <- app_p/14.696*101325
  v_ini <- (2*app_p_pa/rhosoln)^0.5*100 # in cm/sec

  # Calculate the three velocity parts: straight down, downwind, upwind
  Vz1 <- -v_ini
  Vx1 <- 0
  Vz2 <- -v_ini*cos(angle/3*pi/180)
  Vx2 <- v_ini*sin(angle/3*pi/180)
  Vz3 <- -v_ini*cos(angle/3*pi/180)
  Vx3 <- -v_ini*sin(angle/3*pi/180)

  return(c(Vz1, Vx1, Vz2, Vx2, Vz3, Vx3))
}
