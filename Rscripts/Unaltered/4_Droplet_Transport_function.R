# 4_Droplet Transport
droplet_transport<-function(Tair,RH,rhow,rhos,xs0,H0,DTwb,hcm,Uf,z0,Pn,vz0,vx0,ddd_inp){
#  # Clear all memory
#  rm(list = ls())
  
  # # Start the clock!
  # ptm <- proc.time()
  
  # Load libraries
  library(deSolve)
  library(nleqslv)

  # #____________________________________
  # # User Inputs:
  # Tair<-17.689  # Ambient Air temperature, C
  # RH<-35.65     # Relative Humidity of Ambient Air, %
  # 
  # rhow<-1 # Density of pure water in droplet
  # rhos<-2.01594  # Density of dissolved solids in droplet, g/cc
  # xs0<-0.019369  # mass fraction total dissolved solids in solution
  # 
  # H0<-24 # Height of nozzle above ground , inches
  # DTwb<-7.696 # Wetbulb temperature depression, C
  # hcm<-0 # Canopy height in cm
  # 
  # 
  # # Wind horozontal velocity parameters
  # Uf<-43.66 # Friction velocity parameter, cm/sec
  # 
  # z0<-1.063 # Friction height, cm
  # 
  # Pn<-63 # Nozzle pressure, psi
  # 
  # # Liquid sheet vector velocity from nozzle in cm/sec
  # vz0<--2352.6 # Vertical velocity in cm/sec
  # vx0<--1751.5 # Horizontal velocity in cm/sec
  # ddd<-c(40,40,40,1.05,1.05,1.05,1.05,1.05,1.05,1.05,1.05,1.02,1.02,10,10,10,10,1.04,1.04,1.04,20,10,10)
  
  #____________________________________

  rhoL0<-1/(xs0/rhos+(1-xs0)/rhow) # Initial solution density (as applied), gram/cm^3
  # rhoL0 correct value,; AV 11202019
  
  # Constants:
  k0<-1.765e-4
  k1<-4.752e-7
  k2<--1.478e-4
  aaaa<-0.001
  
  mwa<-function(T,y){
    k0+k1*T+k2*y
  }
  
  f<-function(Re){
    24/Re*(1+0.197*Re^0.63+0.00026*Re^1.38)
  }
  
  MWs<-200
  
  
  # Horizontal wind velocity profile function, cm/sec .vs. cm:
  Ux<-function(z){
    if(z>z0){
      Uf/0.4*log(z/z0)
    }
    else{
      0
    }
  }
  
  
  
  
  Xf<-(1350/102)^(1/(22-12))
  
  Dp<-c(0) # Initialize
  
  for(i in 1:13){
    Dp[i]<-18+(i-1)*7
  }
  
  for(i in 14:23){
    Dp[i]<-Dp[i-1]*Xf
  }
  # Dp calculated correctly; AV 11202019
  
  Psw<-function(T){
    exp(18.3036+log(1/760)-3816.44/(T+227.02))
  }
  
  #Water Vapor Pessure Equation, in atmospheres, T in C
  gc<-980.1  # Gravitational constant, cm/sec^2
  lea<-4*2.54
  nea<-2
  h0ref<-(H0*2.54-lea) # Calc correct; AV 11202019
  
  MWw<-18.015
  MWair<-0.209*2*15.9994+(1-0.209)*2*14.007
  h0<-(H0*2.54-lea) # Initial elevation of droplet leaving liq sheet in cm # Correct; AV 11202019
  
  lw<-76.4e-8
  ttt<-0
  
  # Vt<-1000
  # Mathcad creates a template function for Vt calculation - maybe not necessary
  #
  #
  #
  #
  #
  
  Tdp<-3816.44/(3816.44/(Tair+227.02)-log(RH/100))-227.02
  DPD<-Tair-Tdp
  Ywinf<-Psw(Tdp)/1
  
  theta<-xs0/rhos/(xs0/rhos+(1-xs0)/rhow)
  
  # Tdp, DPD, Ywinf, theta correct; AV 11202019
  
  rhowa<-function(T,y){
    (MWw*y+MWair*(1-y))/(82.061*(Tair+273.15))
    
  }
  
  rhoa0<-rhowa(Tair,Ywinf) # correct; AV 11202019
  ma0<-mwa(Tair,Ywinf) # correct; AV 11202019
  
  phi<-1
  vwx<-Ux(h0) # correct; AV 11202019
  
  
  # Water evaporation function, grams water/sec
  W<-function(Ms, Mw, Re){
    (3*pi^(2/3)/2/6^(2/3))*(lw*DTwb)*rhow*(Ms/rhos+Mw/rhow)^(1/3)*(1+0.27*Re^0.5)*Mw/(Ms+Mw) # Function correct; AV 11202019
  }
  
  ddd<-40
  
  Vwz<-function(z){
    vz0*ttt*(lea*h0/h0ref/(h0+lea-z))^nea # Function correct; (thought produces zero results in both MathCad and R) AV 11202019
  }
  
  
  # _____________________________________________________________________
  # Loop through all Dp samples
  Xdist<-c(0) # Initialize distance vector
  for (i in 1:23) {
    print(i)
    ddd<-ddd_inp[i]
    # if(i>=4){ddd<-1.05} # Why is ddd Changing
    # if(i>=12){ddd<-1.02} # Why is ddd Changing
    # if(i>=14){ddd<-1.05} # Why is ddd Changing
    # if(i>=18){ddd<-1.04} # Why is ddd Changing
    # if(i>=21){ddd<-20} # Why is ddd Changing
    # if(i>=22){ddd<-10} # Why is ddd Changing
    
    #  dp0<-Dp[1]/10000  # Prototyping here; this is loop 1
    
    dp0<-Dp[i]/10000  # Prototyping here; this is loop 1
    
    
    Ms<-pi/6*dp0^3*xs0/(xs0/rhos+(1-xs0)/rhow) # Function correct; AV 11202019
    Mw0<-pi/6*dp0^3*(1-xs0)/(xs0/rhos+(1-xs0)/rhow) # Function correct; AV 11202019
    
    
    ###### Estimate Vt
    EqnVt<-function(Vt){
      Vt-sqrt(4*dp0*980.1*(rhoL0-rhoa0)/3/rhoa0/f(rhoa0*Vt*dp0/ma0))
    }
    
    Vt<-nleqslv(1000,EqnVt)[1]$x  # Function correct; AV 11202019 
    
    
    timefordeposition<-h0/Vt  # Function correct; AV 11202019
    
    Time1<-timefordeposition*ddd  # Function correct; AV 11202019
    
    N1<-10000
    N2<-10000
    
    N<-ifelse(dp0<150/1e4,N1,N2)
    
    # Ready to solve the ODE
    # Initial States Vector:
    yini<-c(Z=h0,X=0,Vz=vz0,Vx=vx0,Mw=Mw0,Vvwx=vwx)
    # Time Vector:
    times <- seq(0, Time1, by = Time1/N)
    
    # Define the system
    EqnSys<-function(time,state, parms){
      with(as.list(c(state)),{
        
        dVz<-((pi/6*((6/pi*(Mw/rhow+Ms/rhos))^(1/3))^3*gc*(rhoa0-(Mw+Ms)/(Mw/rhow+Ms/rhos))+
                 W(Ms,Mw,(rhoa0*(6/pi*(Mw/rhow+Ms/rhos))^(1/3)*((Vz-Vwz(Z))^2+(Vvwx-Vx)^2)^0.5)/ma0)*Vz+
                 pi*f((rhoa0*(6/pi*(Mw/rhow+Ms/rhos))^(1/3)*((Vz-Vwz(Z))^2)^0.5)/ma0)*rhoa0*((6/pi*(Mw/rhow+Ms/rhos))^(1/3))^2*(-Vz+Vwz(Z))*abs(-Vz+Vwz(Z))/8))/(Mw+Ms)*ifelse(Z<=z0,0,1)
        dMw<--W(Ms,Mw,(rhoa0*(6/pi*(Mw/rhow+Ms/rhos))^(1/3)*((Vz-Vwz(Z))^2+(Vvwx-Vx)^2)^0.5)/ma0)*ifelse(Z<=z0,0,1)
        dVx<-((Vx*W(Ms,Mw,(rhoa0*(6/pi*(Mw/rhow+Ms/rhos))^(1/3)*((Vz-Vwz(Z))^2+(Vvwx-Vx)^2)^0.5)/ma0)+
                 pi*f((rhoa0*(6/pi*(Mw/rhow+Ms/rhos))^(1/3)*((Vx-Vvwx)^2)^0.5)/ma0)*rhoa0*((6/pi*(Mw/rhow+Ms/rhos))^(1/3))^2*(Vvwx-Vx)*abs(Vvwx-Vx)/8))/(Mw+Ms)*ifelse(Z<=z0,0,1)*ifelse(Vvwx<=0,0,1)
        dX<-Vx*ifelse(Z<=z0,0,1)
        dZ<-Vz*ifelse(Z<=z0,0,1)
        dVvwx<-ifelse(Z>z0,Uf/0.4/Z*Vz,0)*ifelse(Z<=z0,0,1)
        
        
        return(list(c(dZ,dX,dVz,dVx,dMw,dVvwx)))
      })
    }
    
    Xdist[i]<-0 # reset in case no convergence below
    
    # Solve the system
    try({
      out   <- ode(yini, times, EqnSys)
      Xdist[i]<-out[N-1,3]/12/2.54},
      silent=TRUE)  #AV revified results for Z, X are correct;  AV 11202019
    
    if (Xdist[i]==0){
      print("Trying alternate solution")
      # Solve the system with Euler if failed before
      try({
        out   <- ode(yini, times, EqnSys,parms=0,method="euler",maxsteps=1e4)
        Xdist[i]<-out[N-1,3]/12/2.54},
        silent=TRUE)  #AV revified results for Z, X are correct;  AV 11202019
    }
    
    # Solve the system using error control; if lsoda fails try to converge with euler
#    tryCatch(out   <- ode(yini, times, EqnSys,parms=0,method="lsoda",maxsteps=1e4),finally=out<- ode(yini, times, EqnSys,parms=0,method="euler",maxsteps=1e4))  #AV verified results for Z, X are correct;  AV 11202019
    # print(out)
    #  summary(out)
    #  plot(out)
    #  Df1<-10000*(6/pi*(out[N,6]/rhow+Ms/rhos))^(1/3)  #AV revified results for Df are correct; AV 11202019
#    Xdist[i]<-out[N-1,3]/12/2.54
    
  }
  
  # out[N-1,]
  # Xdist
  # dp0
  # Df1
  
  return(data.frame(Dp[1:23],Xdist))  # AV checked result and is correct
  # # Stop the clock
  # proc.time() - ptm
  # 
  
  
}