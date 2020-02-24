# 3_WV2measurements

WV2m<-function(z1,z2,ux1,ux2){
  
# Two wind measurements (elevationin feet, speed in mph):
  z1<-6.6
  z2<-1.67
  ux1<-13.5
  ux2<-9.44
  
  Uf<-slope*0.4 # ( in cm/s)
  z0<-exp(-intercept*0.4/Uf)
  
  return(z0)
  
}