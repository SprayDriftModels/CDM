WV2m <- function(z1, z2, ux1, ux2){
  
  slope <- (44.704*ux1-44.704*ux2)/(log(30.48*z1)-log(30.48*z2))
  Uf <- slope*0.4 # ( in cm/s)
  intercept <- 44.704*ux1-slope*log(30.48*z1)
  
  z0 <- exp(-intercept*0.4/Uf)
  
  return(c(z0,Uf))
}