wvprofile<-function(lambda,hcin,h0in,zft,Vmph){
  
# This estimates the wind velocity profile above and within a canopy
# given canopy height, wind velocity at a specifies hiehgt, and a vegetation
# area ration parameter.

## Clear all memory
#rm(list = ls())

# Load libraries
library(nleqslv)

#lambda<-0.08  # Project area ratio of vegetation in wind direction per area of ground surfaca
#hcin<-4 # canopy height, inches
#h0in<-20 #boom height above canopy, inches
#zft<-6.6 # elevation of wind velocity in ft
#Vmph<-12.8 # mph wind velocity at elevation


hc<-hcin*2.54 # canopy height, cm
psi<-log(2)-1+0.5

h0cm<-h0in*2.54 #boom height above canopy, cm

tau<-min(0.3,sqrt(0.003+0.3*lambda)) # ratio of U/Uh  #AV01172020; correct

d<-hc*(1-(1-exp(-sqrt(15*lambda)))/sqrt(15*lambda)) # initializzed value for zeo plane displacement, cm # AV01172020; correct

z0_ini<-hc*((1-d/hc)*exp(-0.4/tau-psi))



# Various initializations for iterative scheme
h<-h0in*2.54+hc
zcm<-zft*12*2.54
Vcms<-Vmph*5280*12*2.54/3600
UovK<-Vcms/log((zcm-d)/z0_ini)# AV01172020; correct
Uh_ini<-UovK*log((hc-d)/z0_ini)# AV01172020; correct
Ufriction_ini<-UovK*0.4# AV01172020; correct


Kvk<-0.4
epsilon<-1
# k2<-40
#alpha_avg<-2  # Is this needed? MathCAD code has it.
#z1<-hc*1.01

Eqn<-function(X){
  Uh<-X[1]
  Ufriction<-X[2]
  z1<-X[3]
  z0<-X[4]
  alpha_avg<-X[5]
  k2<-X[6]
  
  y<-numeric(6)
  y[1]<-alpha_avg-3.95083*epsilon+3.0375*epsilon*Ufriction/100
  y[2]<-z0-hc*((1-d/hc)*exp(-0.4*Uh/Ufriction-psi))
  y[3]<-Vcms-Ufriction*log((zcm-d)/z0)/Kvk
  y[4]<-Ufriction/Uh-min(0.3,sqrt(0.003+0.3*lambda)/exp(0.5*lambda*Uh/2/Ufriction))
  y[5]<-Ufriction*log((z1-d)/z0)/Kvk-Uh*(z1-z0)/k2*exp(alpha_avg*(z1/hc-1))
  y[6]<-Uh/k2*((z1-z0)*alpha_avg*exp(alpha_avg*(z1/hc-1))/hc+exp(alpha_avg*(z1/hc-1)))-Ufriction/Kvk/(z1-d)
  y
}

Solution<-nleqslv(c(Uh_ini,Ufriction_ini,hc*1.01,z0_ini,2,40),Eqn, control=list(trace=1,btol=.01,delta="cauchy"))[1]$x #AV 01172020; correct
Solution

U<-function(z){
  ifelse(z>Solution[3],Solution[2]/Kvk*log((z-d)/Solution[4]),Solution[1]*(z-Solution[4])/Solution[6]*exp(Solution[5]*(z/hc-1)))*
    ifelse(z<=Solution[4],0,1)
}

x11()
plot(U((1:1000)*h/1000),(1:1000)*h/1000,xlab="Wind Velocity (cm/s)",ylab="Elevation from Ground (cm)",col="red",type="l")
lines(U((1:1000)*h/1000),(1:1000)*0+hc,col="blue")
lines(U((1:1000)*h/1000),(1:1000)*0+Solution[3],col="yellow")
lines(U((1:1000)*h/1000),(1:1000)*0+Solution[6],col="green")
legend(50, 50, legend=c("Wind Velocity", "Canopy Height", "Within Canopy Boundary Layer","Elevation at which Wind Profile Changes"),
       col=c("red", "blue","green","yellow"), lty=c(1,1,1,1), cex=0.8)


return(Solution)
}