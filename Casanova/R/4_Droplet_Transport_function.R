#' Droplet Transportation Calculator
#'
#' @param Tair Dry air temperature, degrees C
#' @param RH Percent relative humidity
#' @param rhow Density of pure water in droplet
#' @param rhos Density of dissolved solids in droplet, g/cc
#' @param xs0 mass fraction total dissolved solids in solution
#' @param H0 Height of nozzle above ground , inches
#' @param DTwb Wetbulb temperature depression, C
#' @param hcm Canopy height in cms
#' @param Uf Friction velocity, cm/sec (uf)
#' @param z0 Friction height, cm (z0)
#' @param Pn  # Nozzle pressure, psi
#' @param vz0 nozzle characteristics 1
#' @param vx0 nozzle characteristics 1
#' @param ddd_inp ddd parameters
#' @param Driver "text","shiny", "Silent"
#'
#' @return Xdist and corresponding transportation.
#' @export
#'
#' @examples
droplet_transport<-function(Tair, RH, rhow, rhos, xs0, H0, DTwb, hcm,Uf, z0, Pn,  vz0, vx0, ddd_inp,
                            Driver){

  rhoL0 <- 1/(xs0/rhos+(1-xs0)/rhow) # Initial solution density (as applied), gram/cm^3

  # Constants:
  k0 <- 1.765e-4
  k1 <- 4.752e-7
  k2 <- -1.478e-4
  aaaa <- 0.001

  mwa <- function(T,y){
    k0+k1*T+k2*y
  }

  f<-function(Re){
    24/Re*(1+0.197*Re^0.63+0.00026*Re^1.38)
  }

  #MWs <- 200 # Not used anywhere


  # Horizontal wind velocity profile function, cm/sec .vs. cm:
  Ux<-function(z){
    if(z>z0){
      Uf/0.4*log(z/z0)
    }
    else{
      0
    }
  }


  Xf <- (1350/102)^(1/(22-12))

  Dp <- c(0) # Initialize

  for(i in 1:13){
    Dp[i]<-18+(i-1)*7
  }

  for(i in 14:23){
    Dp[i]<-Dp[i-1]*Xf
  }

  Psw<-function(T){
    exp(18.3036+log(1/760)-3816.44/(T+227.02))
  }

  #Water Vapor Pressure Equation, in atmospheres, T in C
  gc <- 980.1  # Gravitational constant, cm/sec^2
  lea <- 4*2.54
  nea <- 2
  h0ref <- (H0*2.54-lea)

  MWw <- 18.015
  MWair <- 0.209*2*15.9994+(1-0.209)*2*14.007
  h0 <- (H0*2.54-lea) # Initial elevation of droplet leaving liq sheet in cm

  lw <- 76.4e-8
  ttt <- 0


  Tdp <- 3816.44/(3816.44/(Tair+227.02)-log(RH/100))-227.02
  DPD <- Tair-Tdp
  Ywinf <- Psw(Tdp)/1

  theta <- xs0/rhos/(xs0/rhos+(1-xs0)/rhow)

  rhowa <- function(T,y){
    (MWw*y+MWair*(1-y))/(82.061*(Tair+273.15))  #AV comment 2/24/2021; This function definition does not include T
  }

  rhoa0 <- rhowa(Tair,Ywinf)
  ma0 <- mwa(Tair,Ywinf)

  phi <- 1
  vwx <- Ux(h0)


  # Water evaporation function, grams water/sec
  W<-function(Ms, Mw, Re){
    (3*pi^(2/3)/2/6^(2/3))*(lw*DTwb)*rhow*(Ms/rhos+Mw/rhow)^(1/3)*(1+0.27*Re^0.5)*Mw/(Ms+Mw)
  }

  ddd <- 40

  Vwz <- function(z){
    vz0*ttt*(lea*h0/h0ref/(h0+lea-z))^nea
  }


  # _____________________________________________________________________
  # Loop through all Dp samples

  # Parallelize code by creating a cluster with all available cores:
  cl <- makeCluster(detectCores(), type = "SOCK") #AVP
  registerDoSNOW(cl) #AVP

  Xdist<-c(0) # Initialize distance vector #AVP
  # for (i in 1:23) { #AVP
  Xdist<-foreach(i=1:23, .combine = c, .inorder = TRUE) %dopar% { #AVP
    # Note that Xdist within the foreach loop has scope only within the loop

    # Increment the progress bar, and update the detail text
    if(Driver == "shiny"){
      incProgress(1/23, detail = paste0(round((i/23)*100, digits = 0), "% complete"))
    } else{
      print(i)
    }

    ddd <- ddd_inp[i]

    dp0<-Dp[i]/10000  # Prototyping here; this is loop 1

    Ms <- pi/6*dp0^3*xs0/(xs0/rhos+(1-xs0)/rhow)
    Mw0 <- pi/6*dp0^3*(1-xs0)/(xs0/rhos+(1-xs0)/rhow)


    ###### Estimate Vt
    EqnVt<-function(Vt){
      Vt-sqrt(4*dp0*980.1*(rhoL0-rhoa0)/3/rhoa0/f(rhoa0*Vt*dp0/ma0))
    }

    Vt <- nleqslv(1000,EqnVt)[1]$x


    timefordeposition<-h0/Vt

    Time1 <- timefordeposition*ddd

    N1 <- 10000
    N2 <- 10000

    N <- ifelse(dp0<150/1e4,N1,N2)

    # Ready to solve the ODE
    # Initial States Vector:
    yini <- c(Z=h0,X=0,Vz=vz0,Vx=vx0,Mw=Mw0,Vvwx=vwx)
    # Time Vector:
    times <- seq(0, Time1, by = Time1/N)

    # Define the system
    EqnSys <- function(time,state, parms){
      with(as.list(c(state)),{

        dVz <- ((pi/6*((6/pi*(Mw/rhow+Ms/rhos))^(1/3))^3*gc*(rhoa0-(Mw+Ms)/(Mw/rhow+Ms/rhos))+
                   W(Ms,Mw,(rhoa0*(6/pi*(Mw/rhow+Ms/rhos))^(1/3)*((Vz-Vwz(Z))^2+(Vvwx-Vx)^2)^0.5)/ma0)*Vz+
                   pi*f((rhoa0*(6/pi*(Mw/rhow+Ms/rhos))^(1/3)*((Vz-Vwz(Z))^2)^0.5)/ma0)*rhoa0*((6/pi*(Mw/rhow+Ms/rhos))^(1/3))^2*(-Vz+Vwz(Z))*abs(-Vz+Vwz(Z))/8))/(Mw+Ms)*ifelse(Z<=z0,0,1)
        dMw <- -W(Ms,Mw,(rhoa0*(6/pi*(Mw/rhow+Ms/rhos))^(1/3)*((Vz-Vwz(Z))^2+(Vvwx-Vx)^2)^0.5)/ma0)*ifelse(Z<=z0,0,1)
        dVx <- ((Vx*W(Ms,Mw,(rhoa0*(6/pi*(Mw/rhow+Ms/rhos))^(1/3)*((Vz-Vwz(Z))^2+(Vvwx-Vx)^2)^0.5)/ma0)+
                   pi*f((rhoa0*(6/pi*(Mw/rhow+Ms/rhos))^(1/3)*((Vx-Vvwx)^2)^0.5)/ma0)*rhoa0*((6/pi*(Mw/rhow+Ms/rhos))^(1/3))^2*(Vvwx-Vx)*abs(Vvwx-Vx)/8))/(Mw+Ms)*ifelse(Z<=z0,0,1)*ifelse(Vvwx<=0,0,1)
        dX <- Vx*ifelse(Z<=z0,0,1)
        dZ <- Vz*ifelse(Z<=z0,0,1)
        dVvwx <- ifelse(Z>z0,Uf/0.4/Z*Vz,0)*ifelse(Z<=z0,0,1)

        return(list(c(dZ,dX,dVz,dVx,dMw,dVvwx)))
      })
    }

    #Xdist[i]<-0 # reset in case no convergence below #AVP
    Xdist<-0 # reset in case no convergence below #AVP

    # Solve the system
    try({
      out   <- ode(yini, times, EqnSys)
      #Xdist[i]<-out[N-1,3]/12/2.54}, #Non-parallel
      Xdist<-out[N-1,3]/12/2.54}, #parallel
      silent=TRUE)

    #    if (Xdist[i]==0){ #Non-parallel
    if (Xdist==0){ #parallel
      print("Trying alternate solution")
      # Solve the system with radau if failed before
      try({
        out   <- ode(yini, times, EqnSys,parms=0,method="radau",maxsteps=1e4) # radau instead of euler works better in some cases
        #Xdist[i]<-out[N-1,3]/12/2.54}, #Non-parallel
        Xdist<-out[N-1,3]/12/2.54}, #parallel
        silent=TRUE)
    }
    Xdist
  }


  stopCluster(cl) #parallel
  return(data.frame(Dp[1:23],Xdist))
}
