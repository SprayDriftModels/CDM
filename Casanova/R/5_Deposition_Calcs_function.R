#' Calculate Deposition
#'
#' @param IAR Intended Application Rate for Dicamba, lb/acre
#' @param xactive Dicamba conc in tank solution, wtfraction
#' @param FD Downwind field depth, ft
#' @param PL Crosswind field width, ft
#' @param NozzleSpacing Space between nozzles on Boom, inches
#' @param psipsipsi Horizontal variation in wind direction around mean direction, 1 stdev, in degrees.
#' @param rhoL Density of sprayed solution, grams/cc
#' @param Cent_inp output from droplet transportation
#' @param Dwnd_inp output from droplet transportation
#' @param Uwnd_inp output from droplet transportation
#' @param Dpmax D pmax
#' @param DDpmin DD pmin
#' @param a output from psd function, Calibration results
#' @param MMM original value for integration
#' @param lambda Controls resolution of deposition calculations; higher numbers increase accuracy
#' @param Driver "text","shiny", "Silent"
#' @param curverfitDSD a T/F paramet indicating if curvefitting of DSD data is used
#' @param y Average DSD fit data:
#' @param Dpdata Corresponding droplet size (in microns)
#'
#' @return
#' @export
#'
#' @examples
deposition_calcs<-function(IAR, xactive, FD, PL,NozzleSpacing,psipsipsi, rhoL,Cent_inp,Dwnd_inp,Uwnd_inp,
                           Dpmax, DDpmin,a,MMM,lambda,Driver,curvefitDSD, y, Dpdata){


  v <- FD*PL/43560

  Dpmin <- DDpmin
  k <- seq(1,MMM) # Note the +1 compared to MathCAD notation    #This is not really used

  Dddp <- (Dpmax-Dpmin)/MMM    # This is not really used

  # The following uses either the curve fitted function or interpolation between data:
  if (curvefitDSD==T){
    f<-function(Dp){
      (a[5]/a[3]*exp(-0.5*((Dp-a[1])/a[3])^2)+(1-a[5])/a[4]*exp(-0.5*((Dp-a[2])/a[4])^2))/(2*pi)^0.5*ifelse(Dp>=Dpmax,0,1)
    }
  }
  else{
    Dpdata<-c(Dpdata[1]+(Dpdata[2]-Dpdata[1])/(y[2]-y[1])*(-y[1]),Dpdata)
    y<-c(0,y)
    Dpdata<-c(Dpdata, tail(Dpdata, n=1)+diff(tail(Dpdata,n=2))/diff(tail(y,n=2))*(-tail(y,n=1)))
    y<-c(y,100)
    g<-approxfun(Dpdata, y, method='linear',0,100) # This is the DSD function
    f<-function(Dp){
      (g(Dp+Dp/1000)-g(Dp-Dp/1000))/(Dp/500)/100*ifelse(Dp>=Dpmax,0,1) # This is the derivative divided by 100 to convert back to real numbers rather than %; added the ifelse to be consistent with previous function eventough this is not spelled out in word description
    }
  }

  # browser()
  LvsDpa <- data.frame(
    Dp=c(18.0,25.0,32.0,39.0,46.0,53.0,60.0,67.0,74.0,81.0,88.0,95.0,102.0,132.1,171.0,221.4,286.6,371.1,480.4,622.0,805.4,1042.7,1350.0),
    Cent=Cent_inp,
    Dwnd=Dwnd_inp,
    Uwnd=Uwnd_inp
  )

  dpa <- LvsDpa$Dp
  dpb <- LvsDpa$Dp
  dpc <- LvsDpa$Dp

  Lfta <- LvsDpa$Cent
  Lftb <- LvsDpa$Dwnd
  Lftc <- LvsDpa$Uwnd

  # Linear interpolation functions
  ffa <- approxfun(dpa,Lfta)
  ffb <- approxfun(dpb,Lftb)
  ffc <- approxfun(dpc,Lftc)

  Nsa <- as.integer(FD*12/NozzleSpacing)

  DWsa <- FD/Nsa

  Nda <- Nsa*lambda
  DDp <- 0.5
  zeta <- 2.5

  MM <- as.integer((Dpmax-Dpmin)/DDp)

  Dpavg <- Dpmin+seq(0,MM-1)*DDp
  Dpavg[1] <- 0  # Dpavg matches now exactly MathCAD

  DriftDista <- ffa(Dpavg)
  DriftDista[1] <- 0
  DriftDistb <- ffb(Dpavg)
  DriftDistb[1] <- 0
  DriftDistc <- ffc(Dpavg)
  DriftDistc[1]<0

  Lmax <- max(DriftDista[1],DriftDistb[1],DriftDistc[1]) # This is the original formula that crashed MathCAD
  Lmax <- 750 # This is new eqn for Lmax; this eqn replaces above eqn
  DWda <- Lmax/Nda

  SprayedArea <- FD*PL/43560

  VolumeSprayed <- IAR*SprayedArea*453.6/rhoL/1000/xactive

  VAR <- VolumeSprayed/SprayedArea

  SVPs <- f(Dpavg)*DDp*VolumeSprayed/Nsa

  jj <- c(1:(Nsa+Nda)) # Note that this is +1 compared to MathCAD
  X <- ifelse(jj<=Nsa,DWsa*(0.5+jj-1),FD+(0.5+jj-1-Nsa)*DWda)

  #Initialize matrices:
  DVM <- matrix(nrow=MM,ncol=Nsa+Nda)
  CM <- matrix(nrow=MM,ncol=Nsa+Nda)

  #setup parallel backend to use processors
  cores = detectCores()
  cl <- makeCluster(cores[1]-1) #not to overload computer
  registerDoParallel(cl)

  ## Create progress bar
  # Remove some statements outside loop
  SVPs_3<-SVPs/3
  partial_denom<-tan(psipsipsi*pi*zeta/180)

  for (i in 2:MM) {

      # Increment the progress bar, and update the detail text

    # ifelse is faster function;
    ifelse(Driver == "shiny",incProgress((1/MM)*0.5, detail = paste0(round(((i/MM)*0.5)*100, digits = 0), "% complete - Working on Part 1")),
           ifelse(Driver=="Silent",'',print(paste0(round((i/MM)*100, digits = 0), "% complete - Part 1"))))
#    if(Driver == "shiny"){
#        incProgress((1/MM)*0.5, detail = paste0(round(((i/MM)*0.5)*100, digits = 0), "% complete - Working on Part 1"))
#      } else {
#        if(Driver=="Silent"){
#
#      }else{
#        print(paste0(round((i/MM)*100, digits = 0), "% complete - Part 1"))
#      }}

      for (jj in 1:Nsa){# Note that this is +1 compared to MathCAD
        DVM[i,jj]<-sum(
          ifelse(DriftDista[i]>((jj-1)*DWsa-X[1:jj])&DriftDista[i]<=(jj)*DWsa-X[1:jj],SVPs_3[i],0)+
            ifelse(DriftDistb[i]>((jj-1)*DWsa-X[1:jj])&DriftDistb[i]<=(jj)*DWsa-X[1:jj],SVPs_3[i],0)+
            ifelse(DriftDistc[i]>((jj-1)*DWsa-X[1:jj])&DriftDistc[i]<=(jj)*DWsa-X[1:jj],SVPs_3[i],0))

        CM[i,jj]<-sum(
          ifelse(DriftDista[i]>((jj-1)*DWsa-X[1:jj])&DriftDista[i]<=(jj)*DWsa-X[1:jj],SVPs_3[i],0)/
            (DWsa*(PL+2*(X[jj]-X[1:jj])*partial_denom))+
            ifelse(DriftDistb[i]>((jj-1)*DWsa-X[1:jj])&DriftDistb[i]<=(jj)*DWsa-X[1:jj],SVPs_3[i],0)/
            (DWsa*(PL+2*(X[jj]-X[1:jj])*partial_denom))+
            ifelse(DriftDistc[i]>((jj-1)*DWsa-X[1:jj])&DriftDistc[i]<=(jj)*DWsa-X[1:jj],SVPs_3[i],0)/
            (DWsa*(PL+2*(X[jj]-X[1:jj])*partial_denom)))
      }
  }


  ## Create progress bar

    for (i in 2:MM) {

      # Increment the progress bar, and update the detail text
      #ifelse is faster function; giving it a try
      ifelse(Driver == "shiny",incProgress((1/MM)*0.5, detail = paste0(round(((i/MM)*0.5)*100, digits = 0), "% complete - Working on Part 2")),
      ifelse(Driver=="Silent",'',print(paste0(round((i/MM)*100, digits = 0), "% complete - Part 2"))))

#       if(Driver == "shiny"){
#         incProgress((1/MM)*0.5, detail = paste0(round(((i/MM)*0.5+0.5)*100, digits = 0), "% complete - Working on Part 2"))
#       } else{
#         if(Driver=="Silent"){}else print(paste0(round((i/MM)*100, digits = 0), "% complete - Part 2"))
#       }

      for (jj in (Nsa+1):(Nsa+Nda)){# Note that this is +1 compared to MathCAD
        DVM[i,jj]<-sum(
          ifelse(DriftDista[i]>(FD+(jj-1-Nsa)*DWda-X[1:Nsa])&DriftDista[i]<=FD+(jj-Nsa)*DWda-X[1:Nsa],SVPs_3[i],0)+
            ifelse(DriftDistb[i]>(FD+(jj-1-Nsa)*DWda-X[1:Nsa])&DriftDistb[i]<=FD+(jj-Nsa)*DWda-X[1:Nsa],SVPs_3[i],0)+
            ifelse(DriftDistc[i]>(FD+(jj-1-Nsa)*DWda-X[1:Nsa])&DriftDistc[i]<=FD+(jj-Nsa)*DWda-X[1:Nsa],SVPs_3[i],0))

        CM[i,jj]<-sum(
          ifelse(DriftDista[i]>(FD+(jj-1-Nsa)*DWda-X[1:Nsa])&DriftDista[i]<=FD+(jj-Nsa)*DWda-X[1:Nsa],SVPs_3[i],0)/
            (DWsa*(PL+2*(X[jj]-X[1:Nsa])*partial_denom))+
            ifelse(DriftDistb[i]>(FD+(jj-1-Nsa)*DWda-X[1:Nsa])&DriftDistb[i]<=FD+(jj-Nsa)*DWda-X[1:Nsa],SVPs_3[i],0)/
            (DWsa*(PL+2*(X[jj]-X[1:Nsa])*partial_denom))+
            ifelse(DriftDistc[i]>(FD+(jj-1-Nsa)*DWda-X[1:Nsa])&DriftDistc[i]<=FD+(jj-Nsa)*DWda-X[1:Nsa],SVPs_3[i],0)/
            (DWsa*(PL+2*(X[jj]-X[1:Nsa])*partial_denom)))

      }
    }


  DVM[1,] <- 0 # Since i in Mathcad starts from 1 (i.e., first element assumed zero)
  CM[1,] <- 0 # Since i in Mathcad starts from 1 (i.e., first element assumed zero)

  VPS <- matrix(nrow=(Nsa+Nda),ncol=1)
  VPS <- foreach(jj=1:(Nsa+Nda), .combine = c) %dopar% {
    VPS[jj] <- sum(DVM[,jj],na.rm=TRUE)  # Check for the last line of N/A in DMV and CM
  }

  TV <- sum(VPS[1:Nsa])

  DriftedVolumebeyondLmax <- VolumeSprayed-TV

  AppliedRate <- VolumeSprayed/PL/FD

  # Without plume:
  NPDR <- matrix(nrow=Nsa+Nda,ncol=1)
  NPDR <- foreach(jj=1:(Nsa+Nda), .combine = c) %dopar% {

    NPDR[jj]<-VPS[jj]/PL/ifelse(jj<=Nsa,DWsa,DWda)
  }

  CS <- matrix(nrow=MM,ncol=1)
  CS <- foreach(jj=1:(Nsa+Nda),.combine=c) %dopar% {
    CS[jj]<-sum(CM[,jj],na.rm=TRUE)*100/AppliedRate
  }

  PercAppliedwithPlume <- CS
  PercAppliednoPlume <- 100*NPDR/AppliedRate


  g <- approxfun(X-FD,PercAppliedwithPlume[1:length(X)])  #
  gg <- approxfun(X-FD,PercAppliednoPlume[1:length(X)])  #

  N <- 100
  i <- 1:N
  DX <- Lmax/N
  XX <- DX*i-DX

  APplume <- g(XX)
  APnplume <- gg(XX)

  gnef1 <- approxfun(X-FD,PercAppliedwithPlume[1:length(X-FD)])
  gnef2 <- approxfun(X-FD,PercAppliednoPlume)

  k0 <- gnef1(0)
  n <- 1
  k1 <- 0.4

  fg<-function(k0,k1,n,x){
    (k0+k1*x)/(1+k1*x)^n
  }

  # New edited function below
  SSE<-function(Xvar){
    sum(abs(ifelse(APplume[2:N]<=0,1,log(APplume[2:N]))-log(fg(k0,Xvar[1],Xvar[2],XX[2:N])))*ifelse(APplume[2:N]<=0,0,1)/abs(ifelse(APplume[2:N]<=0,1,log(APplume[2:N]))))
  }

  res <- nlm(SSE,c(k1,n))
  k1 <- res$estimate[1]
  n <- res$estimate[2]

  err <- 0.7
  YYYY <- fg(k0,k1,n,XX)

  ## Create tibble for plotting
  dep_data <- tibble("XX" = XX, "APplume" = APplume)

  ## Plot
  dep_plot <- ggplot(dep_data, aes(x = XX, y = APplume)) +
    geom_point(size = 3, alpha = 0.5) +
    scale_colour_manual(values = "#008900") +
    scale_y_continuous(trans='log10') +
    ylab("Deposition (Fraction of Applied)") +
    xlab("Distance (ft)") +
    theme_bw() +
    theme(
      legend.title = element_blank(),
      legend.background = element_rect(fill=alpha('white', 0.4)),
      legend.position = "right",
      legend.text = element_text(size = 16),
      axis.line = element_line(colour = "black"),
      axis.text.y = element_text(size = 16),
      axis.text.x = element_text(size = 16),
      axis.title.y = element_text(size = 16, vjust= 1.5),
      axis.title.x = element_text(size = 16)
    )

  ## Create list of outputs
  dep.list <- list("XX" = XX,
                   "APplume" = APplume,
                   "dep_plot" = dep_plot)

  stopCluster(cl) #AVP
  return(dep.list)
}
