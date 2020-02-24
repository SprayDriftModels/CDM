wvprofile <- function(lambda,hcin,h0in,zft,Vmph){

hc <- hcin*2.54 # canopy height, cm
psi <- log(2)-1+0.5
  
h0cm <- h0in*2.54 #boom height above canopy, cm
  
tau <- min(0.3,sqrt(0.003+0.3*lambda)) # ratio of U/Uh
  
d <- hc*(1-(1-exp(-sqrt(15*lambda)))/sqrt(15*lambda)) # initialized value for zero plane displacement, cm 
  
z0_ini <- hc*((1-d/hc)*exp(-0.4/tau-psi))
  


# Various initializations for iterative scheme
h <- h0in*2.54+hc
zcm <- zft*12*2.54
Vcms <- Vmph*5280*12*2.54/3600
UovK <- Vcms/log((zcm-d)/z0_ini)
Uh_ini <- UovK*log((hc-d)/z0_ini)
Ufriction_ini <- UovK*0.4

Kvk <- 0.4
epsilon <- 1

Eqn <- function(X){
  Uh <- X[1]
  Ufriction <- X[2]
  z1 <- X[3]
  z0 <- X[4]
  alpha_avg <- X[5]
  k2 <- X[6]
  
  y <- numeric(6)
  y[1] <- alpha_avg-3.95083*epsilon+3.0375*epsilon*Ufriction/100
  y[2] <- z0-hc*((1-d/hc)*exp(-0.4*Uh/Ufriction-psi))
  y[3] <- Vcms-Ufriction*log((zcm-d)/z0)/Kvk
  y[4] <- Ufriction/Uh-min(0.3,sqrt(0.003+0.3*lambda)/exp(0.5*lambda*Uh/2/Ufriction))
  y[5] <- Ufriction*log((z1-d)/z0)/Kvk-Uh*(z1-z0)/k2*exp(alpha_avg*(z1/hc-1))
  y[6] <- Uh/k2*((z1-z0)*alpha_avg*exp(alpha_avg*(z1/hc-1))/hc+exp(alpha_avg*(z1/hc-1)))-Ufriction/Kvk/(z1-d)
  y
}

Solution <- nleqslv(c(Uh_ini,Ufriction_ini,hc*1.01,z0_ini,2,40),Eqn, control=list(trace=1,btol=.01,delta="cauchy"))[1]$x


## Return just the parameters of interest
wvprofile_params <- c(Solution[4], Solution[2])

## Plotting

U <- function(z){
  ifelse(z>Solution[3],Solution[2]/Kvk*log((z-d)/Solution[4]),Solution[1]*(z-Solution[4])/Solution[6]*exp(Solution[5]*(z/hc-1)))*
    ifelse(z<=Solution[4],0,1)
}

x <- U((1:1000)*h/1000)
y_wind_vel <- (1:1000)*h/1000
y_can_h <- (1:1000)*0+hc
y_can_bnd_lyr <- (1:1000)*0+Solution[3]
y_el_wind_prof_change <- (1:1000)*0+Solution[6]


wv_plotting <- tibble(x = x,
                      "Wind velocity" = y_wind_vel,
                      "Canopy height" = y_can_h,
                      "Within canopy boundary layer" = y_can_bnd_lyr,
                      "Elevation at which wind profile changes" = y_el_wind_prof_change)

wv_plotting_long <- pivot_longer(wv_plotting,
                                 -x,
                                 names_to = "Variable",
                                 values_to = "Value") %>%
                                 mutate(Variable = as.factor(Variable))


wv_plot <- ggplot(wv_plotting_long, aes(x = x, y = Value, color = Variable)) +
  geom_line(size = 2, alpha = 0.7) +
  scale_color_manual(values = c("#3A405A", "#C9C164", "#BF4342", "#AEC5EB")) +
  ylab("Elevation from Ground (cm)") +
  xlab("Wind Velocity (cm/s)") +
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
wvprofile.list <- list("params" = wvprofile_params,
                       "wv_plot" = wv_plot)

return(wvprofile.list)
}