charact_cal<-function(app_p,angle, p,NF){

# app_p<-63
# p<-c(20,30,40,50,60,70,80)
# NF<-c(0.28,0.35, 0.4,0.45, 0.49,0.53,0.57)

# Calculate mix density (rows 25 to 42)
rhosoln<-1008.7 # in kg/m^3


# Flow at app_p
p<-log(p)
NF<-log(NF)
a<-data.frame(p,NF)
b<-lm(NF~p,a)
intercept<-b$coefficients[[1]]
slope<-b$coefficients[[2]]

flow<-exp(intercept)*app_p^slope
  
app_p_pa<-app_p/14.696*101325
v_ini<-(2*app_p_pa/rhosoln)^0.5*100 # in cm/sec

# Calculate the three velocity parts: straight down, downwind, upwind
Vz1<--v_ini
Vx1<-0
Vz2<--v_ini*cos(angle/3*pi/180)
Vx2<-v_ini*sin(angle/3*pi/180)
Vz3<--v_ini*cos(angle/3*pi/180)
Vx3<--v_ini*sin(angle/3*pi/180)

return(c(Vz1,Vx1,Vz2,Vx2,Vz3,Vx3))

}