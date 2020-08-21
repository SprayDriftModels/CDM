#' Wet Bulb Depression
#'
#' @param Tair 
#' @param Patm 
#' @param RH 
#'
#' @return
#' @export
#'
#' @examples
wet_bulb<-function(Tair, Patm, RH) {# 2_wet_bulb
  
  # This template calculates the Dry and Wet Bulb Temperatures, and the wet bulb temperature depression for air from rigorous 
  # equations. User must specify the Dry Air T (Tair), the %RH, and the barometric pressure (Patm). Pressures are in mmHg abs, and temperatures are in °C.
  
  # Constants:
  aw <- 18.92676
  bw <- -4169.627
  cw <- -33.568
  air <- 6.917
  bair <- 9.911e-4
  cair <- 7.627e-7
  dair <- -4.696e-10
  Dh0 <- 717.2184
  n <- 0.33246
  
  MWair <- 2*(0.79*14.007+0.21*15.994)
  MWw <- 2*1.008+15.9994
  
  Psw <- function(T){
    exp(aw+bw/(T+273.15+cw))  # Antoine vapor pressure for water in mmHg, T in °C - constants regressed for high accuracy between -10 and 50°C
  }
  
  Cpair <- function(T){
    (air+bair*T+cair*T^2+dair*T^3)/MWair    # Air heat capacity equation .vs. T, in cal/g air-°C
  }
  
  DHv <- function(T){
    
    Dh0*(1-(T+273.15)/647.3)^n   # Heat of vaporization for water .vs. T, in cal/g water
    
  }
  
  Tdp <- bw/(log(Psw(Tair)*RH/100)-aw)-273.15-cw
  
  yw <- RH*Psw(Tdp)/100/Patm
  
  omega <- yw*MWw/(1-yw)/MWair
  
  
  # Solve
  Eqn<-function(T){
    Psw(Tdp)-Psw(T)-Patm*MWair/MWw*Cpair(T)*(T-Tair)/DHv(T)
  }
  
  Twb <- nleqslv(0,Eqn)[1]$x  
  
  DTwb <- Tair-Twb # Wet bulb T depression - i.e., driving force for heat transfer from air to droplet surface, °C
  
  return(c(DTwb, Twb))
}