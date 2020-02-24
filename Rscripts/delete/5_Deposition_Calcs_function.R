#5_Deposition_Calcs
deposition_calcs<-function(){
  
  # Clear all memory
  rm(list = ls())
  
  # Close all x11s
  graphics.off()
  
  # Start the clock!
  ptm <- proc.time()
  
  # Libraries
  library(doParallel)
  library(foreach)
  
  
  # User Inputs:
  IAR<-0.4996 #Intended Application Rate for Dicamba, lb/acre
  xactive<-0.003884 #Dicamba conc in tank solution, wtfraction
  FD<-240.16 # Downwind field depth, ft
  PL<-787.4 # Crosswind field width, ft
  NozzleSpacing<-20 # Space between nozzles on Boom, inches
  psipsipsi<-10.7 # Horizontal variation in wind direction around mean direction, 1 stdev, in degrees.
  rhoL<-1.0084 # Density of sprayed solution, grams/cc
  
  v<-FD*PL/43560 # Correct; AV 11212019
  
  
  Dpmax<-1350
  DDpmin<-18
  
  Dpmin<-DDpmin
  MMM<-500
  k<-seq(1,MMM) # Note the +1 compared to MathCAD notation
  
  Dddp<-(Dpmax-Dpmin)/MMM
  
  a<-c(380.638,863.849,128.461,244.358,0.178)
  
  f<-function(Dp){
    (a[5]/a[3]*exp(-0.5*((Dp-a[1])/a[3])^2)+(1-a[5])/a[4]*exp(-0.5*((Dp-a[2])/a[4])^2))/(2*pi)^0.5*ifelse(Dp>=Dpmax,0,1) # Function correct; AV 11212016
    
  }
  
  
  LvsDpa<-data.frame(
    Dp=c(18.0,25.0,32.0,39.0,46.0,53.0,60.0,67.0,74.0,81.0,88.0,95.0,102.0,132.1,171.0,221.4,286.6,371.1,480.4,622.0,805.4,1042.7,1350.0),
    Cent=c(6074.3077395014800,3008.2711710000700,1702.2565938512800,158.8870043040930,111.5875319864090,80.5230949159303,58.3746456679478,40.9386212100869,27.7852429177426,20.6425385026667,15.8727589758146,12.4100870734410,9.7762212414321,3.3389046227334,0.5308583135306,0.1405814853959,0.0611040296598,0.0320750980311,0.0185969534580,0.0114569125157,0.0073482842755,0.0048487954490,0.0032676033206),
    Dwnd=c(6109.0004010223400,3038.2405125546000,1728.7395743989300,159.8149880902540,112.6235491719470,81.7560172281201,59.9877729510145,43.6458353627741,30.4196919274483,22.9969411330500,18.1125086436096,14.6008429009690,11.9512268187871,5.5734905904742,2.5350482785354,1.7507450326249,1.5263877993506,1.4163252068338,1.3513103140577,1.3095967117924,1.2815972828816,1.2622626663387,1.2486430939340),
    Uwnd=c(6108.9424598105100,3038.1452360895400,1728.5991924404000,159.5741959274380,112.3063575445070,81.3549649606991,59.4959622726660,43.0576746069967,29.7258346550706,22.1908770208012,17.1897045643011,13.5564926167946,10.7806116323463,3.8148881046676,0.0345609884263,-0.8762399709143,-1.0539917896701,-1.1227289328319,-1.1567684338184,-1.1758027715635,-1.1872409303725,-1.1944459195259,-1.1991356849360)
  )
  
  dpa<-LvsDpa$Dp
  dpb<-LvsDpa$Dp
  dpc<-LvsDpa$Dp
  
  Lfta<-LvsDpa$Cent
  Lftb<-LvsDpa$Dwnd
  Lftc<-LvsDpa$Uwnd
  
  # Linear interpolation functions 
  ffa<-approxfun(dpa,Lfta)
  ffb<-approxfun(dpb,Lftb)
  ffc<-approxfun(dpc,Lftc)
  
  
  Nsa<-as.integer(FD*12/NozzleSpacing) # Correct; AV 11242019
  
  DWsa<-FD/Nsa
  
  lambda<-3 # Controls resolution of deposition calculations; higher numbers increase accuracy
  
  Nda<-Nsa*lambda
  DDp<-0.5
  zeta<-2.5
  
  MM<-as.integer((Dpmax-Dpmin)/DDp) # Correct; AV 11212019
  
  
  Dpavg<-Dpmin+seq(0,MM-1)*DDp
  Dpavg[1]<-0  # Dpavg matches now exactly MathCAD; Is this correct though?
  
  DriftDista<-ffa(Dpavg)
  DriftDista[1]<-0
  DriftDistb<-ffb(Dpavg)
  DriftDistb[1]<-0
  DriftDistc<-ffc(Dpavg)
  DriftDistc[1]<0
  # All the above DriftDista,b,c vectors are correct; AV 11252019
  
  Lmax<-max(DriftDista[1],DriftDistb[1],DriftDistc[1]) # This is the original formula that crashed MathCAD
  Lmax<-750 # This is new eqn for Lmax; this eqn replaces above eqn
  DWda<-Lmax/Nda # correct; AV 11252019
  
  
  SprayedArea<-FD*PL/43560 # correct; AV 11212019
  
  VolumeSprayed<-IAR*SprayedArea*453.6/rhoL/1000/xactive
  
  VAR<-VolumeSprayed/SprayedArea # Correct; AV 11242019
  
  SVPs<-f(Dpavg)*DDp*VolumeSprayed/Nsa # Correct; AV 11242019
  
  jj<-c(1:(Nsa+Nda)) # Note that this is +1 compared to MathCAD
  X<-ifelse(jj<=Nsa,DWsa*(0.5+jj-1),FD+(0.5+jj-1-Nsa)*DWda) # Correct; AV11242019
  
  #Initialize matrices:
  DVM<-matrix(nrow=MM,ncol=Nsa+Nda)
  CM<-matrix(nrow=MM,ncol=Nsa+Nda)
  
  #setup parallel backend to use many processors
  cores=detectCores()
  cl <- makeCluster(cores[1]-1) #not to overload your computer
  registerDoParallel(cl)
  
  for (i in 2:MM) {
    # DVM<-foreach(i=1:MM,combine=cbind) %:%
    # foreach(jj=1:Nsa, .combine = c) %dopar% { 
    for (jj in 1:Nsa){# Note that this is +1 compared to MathCAD
      DVM[i,jj]<-sum(
        ifelse(DriftDista[i]>((jj-1)*DWsa-X[1:jj])&DriftDista[i]<=(jj)*DWsa-X[1:jj],SVPs[i]/3,0)+
          ifelse(DriftDistb[i]>((jj-1)*DWsa-X[1:jj])&DriftDistb[i]<=(jj)*DWsa-X[1:jj],SVPs[i]/3,0)+
          ifelse(DriftDistc[i]>((jj-1)*DWsa-X[1:jj])&DriftDistc[i]<=(jj)*DWsa-X[1:jj],SVPs[i]/3,0))
      
      #   CM[i,]<-foreach(jj=1:Nsa, .combine = c) %dopar% {
      CM[i,jj]<-sum(
        ifelse(DriftDista[i]>((jj-1)*DWsa-X[1:jj])&DriftDista[i]<=(jj)*DWsa-X[1:jj],SVPs[i]/3,0)/
          (DWsa*(PL+2*(X[jj]-X[1:jj])*tan(psipsipsi*pi*zeta/180)))+
          ifelse(DriftDistb[i]>((jj-1)*DWsa-X[1:jj])&DriftDistb[i]<=(jj)*DWsa-X[1:jj],SVPs[i]/3,0)/
          (DWsa*(PL+2*(X[jj]-X[1:jj])*tan(psipsipsi*pi*zeta/180)))+
          ifelse(DriftDistc[i]>((jj-1)*DWsa-X[1:jj])&DriftDistc[i]<=(jj)*DWsa-X[1:jj],SVPs[i]/3,0)/
          (DWsa*(PL+2*(X[jj]-X[1:jj])*tan(psipsipsi*pi*zeta/180))))
    }
  }
  
  
  for (i in 2:MM) {
    # foreach(i=1:MM) %dopar% { # Paraller run gives an improvement of ~2
    for (jj in (Nsa+1):(Nsa+Nda)){# Note that this is +1 compared to MathCAD
      DVM[i,jj]<-sum(
        ifelse(DriftDista[i]>(FD+(jj-1-Nsa)*DWda-X[1:Nsa])&DriftDista[i]<=FD+(jj-Nsa)*DWda-X[1:Nsa],SVPs[i]/3,0)+
          ifelse(DriftDistb[i]>(FD+(jj-1-Nsa)*DWda-X[1:Nsa])&DriftDistb[i]<=FD+(jj-Nsa)*DWda-X[1:Nsa],SVPs[i]/3,0)+
          ifelse(DriftDistc[i]>(FD+(jj-1-Nsa)*DWda-X[1:Nsa])&DriftDistc[i]<=FD+(jj-Nsa)*DWda-X[1:Nsa],SVPs[i]/3,0))
      
      CM[i,jj]<-sum(
        ifelse(DriftDista[i]>(FD+(jj-1-Nsa)*DWda-X[1:Nsa])&DriftDista[i]<=FD+(jj-Nsa)*DWda-X[1:Nsa],SVPs[i]/3,0)/
          (DWsa*(PL+2*(X[jj]-X[1:Nsa])*tan(psipsipsi*pi*zeta/180)))+
          ifelse(DriftDistb[i]>(FD+(jj-1-Nsa)*DWda-X[1:Nsa])&DriftDistb[i]<=FD+(jj-Nsa)*DWda-X[1:Nsa],SVPs[i]/3,0)/
          (DWsa*(PL+2*(X[jj]-X[1:Nsa])*tan(psipsipsi*pi*zeta/180)))+
          ifelse(DriftDistc[i]>(FD+(jj-1-Nsa)*DWda-X[1:Nsa])&DriftDistc[i]<=FD+(jj-Nsa)*DWda-X[1:Nsa],SVPs[i]/3,0)/
          (DWsa*(PL+2*(X[jj]-X[1:Nsa])*tan(psipsipsi*pi*zeta/180))))
      
    }
  }
  
  
  DVM[1,]<-0 # Since i in Mathcard starts from 1 (i.e., first element assumed zero)
  CM[1,]<-0 # Since i in Mathcard starts from 1 (i.e., first element assumed zero)
  
  VPS<-matrix(nrow=(Nsa+Nda),ncol=1)
  VPS<-foreach(jj=1:(Nsa+Nda), .combine = c) %dopar% {
    # for (jj in 1:(Nsa+Nda)){     # non-parallel loop
    VPS[jj]<-sum(DVM[,jj],na.rm=TRUE)  # Check for the last line of N/A in DMV and CM
  }
  
  
  TV<-sum(VPS[1:Nsa])
  
  DriftedVolumebeyondLmax<-VolumeSprayed-TV
  
  AppliedRate<-VolumeSprayed/PL/FD
  
  # Without plume:
  NPDR<-matrix(nrow=Nsa+Nda,ncol=1)
  NPDR<-foreach(jj=1:(Nsa+Nda), .combine = c) %dopar% {
    # for (jj in 1:(Nsa+Nda)){     # non-parallel loop 
    
    NPDR[jj]<-VPS[jj]/PL/ifelse(jj<=Nsa,DWsa,DWda)
  }
  
  CS<-matrix(nrow=MM,ncol=1)
  CS<-foreach(jj=1:(Nsa+Nda),.combine=c) %dopar% {
    # for (jj in 1:(Nsa+Nda)){   # non-parallel loop
    CS[jj]<-sum(CM[,jj],na.rm=TRUE)*100/AppliedRate   
  }
  
  PercAppliedwithPlume<-CS
  PercAppliednoPlume<-100*NPDR/AppliedRate
  
  
  g<-approxfun(X-FD,PercAppliedwithPlume[1:length(X)])  # 
  gg<-approxfun(X-FD,PercAppliednoPlume[1:length(X)])  #
  
  N<-100
  i<-1:N
  DX<-Lmax/N
  XX<-DX*i-DX # Correct; AV 11252019
  
  APplume<-g(XX)
  APnplume<-gg(XX)
  
  gnef1<-approxfun(X-FD,PercAppliedwithPlume[1:length(X-FD)])    
  gnef2<-approxfun(X-FD,PercAppliednoPlume)    
  
  k0<-gnef1(0) # Result marginally different from MathCAD
  n<-1
  k1<-0.4
  
  fg<-function(k0,k1,n,x){
    (k0+k1*x)/(1+k1*x)^n    # Function form correct; AV 11242019
  }
  
  ###### From here on: SSE differs: then k1 and n estimates differ!!!!!!!!!!!!!!!!!!!!!
  
  SSE<-function(Xvar){
    sum(abs(ifelse(APplume[2:N]<=0,1,log(APplume[2:N]))-log(fg(k0,Xvar[1],Xvar[2],XX[2:N])))*ifelse(APplume[2:N]<-0,0,1)/abs(ifelse(APplume[2:N]<=0,1,log(APplume[2:N]))))
  }
  
  
  res<-nlm(SSE,c(k1,n))
  k1<-res$estimate[1]  # k1 very similar but slightly larger variance
  n<-res$estimate[2]  # n very similar
  
  
  err<-0.7
  YYYY<-fg(k0,k1,n,XX)
  
  x11()
  plot(XX,APplume,type="p", ylim=c(1e-4,100),log="y") # X and APplume are correct; AV 11252019
  
  # Add the sample solution
  xsample<-c(0,7.5,15,22.5,30,37.5,45,52.5,60,67.5,75,82.5,90,97.5,105,112.5,120,127.5,135,142.5,150,157.5,165,172.5,180,187.5,195,202.5,210,217.5,225,232.5,240,247.5,255,262.5,270,277.5,285,292.5,300,307.5,315,322.5,330,337.5,345,352.5,360,367.5,375,382.5,390,397.5,405,412.5,420,427.5,435,442.5,450,457.5,465,472.5,480,487.5,495,502.5,510,517.5,525,532.5,540,547.5,555,562.5,570,577.5,585,592.5,600,607.5,615,622.5,630,637.5,645,652.5,660,667.5,675,682.5,690,697.5,705,712.5,720,727.5,735,742.5)
  ysample<-c(49.26940583,0.34055937,0.173130105,0.120086902,0.09243854,0.078218327,0.067583261,0.057168197,0.049397177,0.041094409,0.035516801,0.029211938,0.026046156,0.02125432,0.017616106,0.014117701,0.011583983,0.009789691,0.008163677,0.00578978,0.003986984,0.002370035,0.001491139,0.001379418,0.001379048,0.001379063,0.001418411,0.001379328,0.001479585,0.001379288,0.001378919,0.001480785,0.001379258,0.001393787,0.001725388,0.00196828,0.001957695,0.001314,0.001314201,0.001432642,0.001378769,0.001240683,0.001240381,0.00124039,0.001322926,0.001456319,0.001240879,0.001240577,0.001394678,0.001523086,0.001776783,0.001591355,0.001125765,0.001125514,0.001125264,0.001144627,0.001238868,0.001308799,0.001125677,0.001125426,0.001125176,0.00131714,0.00124312,0.001469363,0.001614289,0.001617195,0.001419914,0.001027891,0.001027894,0.001172293,0.00102845,0.001028239,0.001028028,0.001027817,0.001174268,0.001192491,0.001028376,0.001028165,0.001179793,0.001553947,0.001610477,0.001279219,0.000984473,0.000945128,0.000944948,0.000944768,0.000948064,0.001144851,0.000945245,0.000945065,0.000944885,0.000944705,0.001253356,0.001161622,0.001306463,0.001200312,0.001128156,0.000872942,0.00100343,0.000898375)
  lines(xsample, ysample, col="green")
  
  # Stop the clock
  proc.time() - ptm  # 220 secs for non-parallel code;
}