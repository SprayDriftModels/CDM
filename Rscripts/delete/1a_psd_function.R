psd<-function(y, Dpdata){

  Dpmin <- min(Dpdata)
  Dpmax <- max(Dpdata)
  
  # Data frame with data
  all_dp_data <- data.frame(y, Dpdata)
  
  # Function to fit
  f<-function(Dp, a1, a2, d1, d2, k1){
    
    denom11 <- d1*sqrt(2*pi)
    denom12 <- 2*d1^2
    denom21 <- d2*sqrt(2*pi)
    denom22 <- 2*d2^2
    f1<-function(x){exp(-((x-a1)^2)/denom12)/denom11}
    f2<-function(x){exp(-((x-a2)^2)/denom22)/denom21}
    
    funct<-0  
    
    # The following is needed to non-linear curve estimation tool (nls); it needs output to be a vector
    for (i in 1: length(Dp))
    {
      temp <- 100*(k1*integrate(f1,Dpmin,Dp[[i]])$value+(1-k1)*integrate(f2,Dpmin,Dp[[i]])$value)
      funct <- c(funct,temp)
    }
    funct[-1] # Removes the initialization of the vector
  }
  
  
  m.sinexp <- nls(y ~ f(Dpdata, a1,a2,d1,d2,k1), data = all_dp_data,start = list(a1=300,a2=800,d1=100,d2=200,k1=0.2), 
                  trace = T,
                  control=nls.control(maxiter = 200))
  
  # The above produces slighlty different numbers than the MathCad code but they still calibrate well with data
  
  res <- m.sinexp$m$getPars()
  

  return(res)
}
