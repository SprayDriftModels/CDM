# Function when 1 wind vs. height measurements are available
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
WV2m <- function(z1, z2, ux1, ux2){
  
  slope <- (44.704*ux1-44.704*ux2)/(log(30.48*z1)-log(30.48*z2))
  Uf <- slope*0.4 # ( in cm/s)
  intercept <- 44.704*ux1-slope*log(30.48*z1)
  
  z0 <- exp(-intercept*0.4/Uf)
  
  return(c(z0, Uf))
}