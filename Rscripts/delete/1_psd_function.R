psd<-function(y,Dpdata){
#  # Clear all memory
#  rm(list = ls())
  
  # Load libraries
  library(nlstools)
  
  # User Input (the following are directly provided by the main driver):
  #  # Average DSD fit data:
  #  y<-c( 0.000000,	0.000567,	0.002167,	0.005800,	0.011267,	0.018667,	0.031733,	0.053300,	0.086867,	0.128467,	0.194733,	0.291667,	0.421867,	0.581300,	0.759500,	0.933300,	0.999900,	1.000000)
  #  y<-100*y
  
  #  # Corresponding droplet size (in microns):
  #  Dpdata<-c( 86, 100, 120, 150, 180, 210, 250, 300, 360, 410, 500, 600, 720, 860, 1020, 1220, 1460, 1740)
  
  
  Dpmin<-min(Dpdata)
  Dpmax<-max(Dpdata)
  
  # Data frame with data
  all_dp_data<-data.frame(y,Dpdata)
  
  # Function to fit
  f<-function(Dp, a1,a2,d1,d2,k1){
    
    denom11<-d1*sqrt(2*pi)
    denom12<-2*d1^2
    denom21<-d2*sqrt(2*pi)
    denom22<-2*d2^2
    f1<-function(x){exp(-((x-a1)^2)/denom12)/denom11}
    f2<-function(x){exp(-((x-a2)^2)/denom22)/denom21}
    
    funct<-0  
    
    # The following is needed to non-linear curve estimation tool (nls); it needs output to be a vector
    for (i in 1: length(Dp))
    {
      temp<-100*(k1*integrate(f1,Dpmin,Dp[[i]])$value+(1-k1)*integrate(f2,Dpmin,Dp[[i]])$value)
      funct<-c(funct,temp)
    }
    funct[-1] # Removes the initialization of the vector
    
    # AV verified that the equation is input correctly on 11182019  
  }
  
  
  m.sinexp <- nls(y ~ f(Dpdata, a1,a2,d1,d2,k1), data = all_dp_data,start = list(a1=300,a2=800,d1=100,d2=200,k1=0.2), 
                  trace = T)
  
  # The above produces slighlty different numbers than the MathCad code but they still calibrate well with data
  
  res<-m.sinexp$m$getPars()
  
  # Plot the calibration with the input data
  Dp_plot<-(18:1460)
  fDP_plot<-1/(2*pi)^0.5*(res[[5]]/res[[3]]*exp(-1*(Dp_plot-res[[1]])^2/2/res[[3]]^2)+(1-res[[5]])/res[[4]]*exp(-1*(Dp_plot-res[[2]])^2/2/res[[4]]^2))
  
  Y<-0
  for (i in 2:length(Dp_plot<-(18:1460))){
    Y[i]<-Y[i-1]+(fDP_plot[i-1]+fDP_plot[i])/2*(Dp_plot[i]-Dp_plot[i-1])*100
  }
  
  x11()
  plot(Dp_plot,Y, xlab='Droplet Size (microns)',ylab='Percentage (%)',lty=1,lwd=0.05)
  points(Dpdata,y,pch=17,col='red')
  legend(1, 95, legend=c("Input Data", "Calibrated"),
         col=c("red", "black"), pch=c(17,0),lty=c(0,1), cex=0.8)
  return(res)
}
