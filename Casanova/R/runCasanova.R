#' Title Run casanova as all
#'
#' @param dsdTable dsd data as a table, use this when dsdFile is not provided.
#' @param dsdFile read in a csv file input and use that as the table
#' @param inputs an R file defining all the inputs, and it could be modified!
#' @param NozzleParamFile nozzle parameter file
#' @param DDDParamsFile DDD parameter file
#'
#' @return a list containing all droplet data and deposition
#' @export
#'
#' @examples
runCasanova <- function(dsdTable,dsdFile=NULL,inputs="DefaultInputs.R",NozzleParamFile="~/mondep/Casanova/data-raw/Nozzle_Params.csv",DDDParamsFile="~/mondep/Casanova/data-raw/DDD_Params.csv"){
  results <- NULL
  if(is.character(dsdFile)) dsdTable <- read_csv(dsdFile)## else dsdFile should be a table.
  dsdFile <- dsdTable%>% mutate(ymean=(Trial_1+Trial_2+Trial_3)/3)

  ## Determine where to draw the cut-off (begin with first value over zero and end with first value that reaches 100)
  firsty <- min(which(dsdFile$ymean > 0))
  lasty <- max(which(dsdFile$ymean < 100)) + 1

  y <-  dsdFile$ymean %>%
    tibble::enframe() %>%
    slice(firsty:lasty) %>%
    pull(value)
  Dpdata <- dsdFile$Droplet_Size_microns%>%tibble::enframe() %>%
    slice(firsty:lasty) %>%
    pull(value)
  pars <- psd(y,Dpdata)

  source(inputs)
  results$pars <- pars


  ## Load hard-coded inputs
  Nozzle_params <- as_tibble(read.csv(NozzleParamFile, header = T))
  DDD_params <- as_tibble(read.csv(DDDParamsFile, header = T))
  p <- Nozzle_params %>% select(p)
  NF <- Nozzle_params %>% select(NF)
  ddd1 <- DDD_params$ddd1
  ddd2 <- DDD_params$ddd2
  ddd3 <- DDD_params$ddd3


  Twb <- wet_bulb(Tair, Patm, RH)
  wv <- WV2m (z1=z1, z2, ux1, ux2)
  z0 <- wv[1]
  Uf <- wv[2]
  charac<-charact_cal(app_p,angle, rhosoln)
  DTwb<-Twb[1] # Wetbulb temperature depression, C
  print("Solving Straight Down Problem")
  droplet_1<-droplet_transport(Tair,RH,rhow,rhos,xs0,H0,DTwb,hcm,Uf,z0,app_p,charac[1],charac[2],ddd1,"Silent")
  print("Solving with Wind Problem")
  droplet_2<-droplet_transport(Tair,RH,rhow,rhos,xs0,H0,DTwb,hcm,Uf,z0,app_p,charac[3],charac[4],ddd2,"text")
  print("Solving against Wind Problem")
  droplet_3<-droplet_transport(Tair,RH,rhow,rhos,xs0,H0,DTwb,hcm,Uf,z0,app_p,charac[5],charac[6],ddd3,"Silent")

  print("Finished Solving for Droplet Transport")
  DTwb<-Twb[1] # Wetbulb temperature depression, C
  print("Solving Straight Down Problem")
  droplet_1<-droplet_transport(Tair,RH,rhow,rhos,xs0,H0,DTwb,hcm,Uf,z0,app_p,charac[1],charac[2],ddd1,"Silent")
  print("Solving with Wind Problem")
  droplet_2<-droplet_transport(Tair,RH,rhow,rhos,xs0,H0,DTwb,hcm,Uf,z0,app_p,charac[3],charac[4],ddd2,"text")
  print("Solving against Wind Problem")
  droplet_3<-droplet_transport(Tair,RH,rhow,rhos,xs0,H0,DTwb,hcm,Uf,z0,app_p,charac[5],charac[6],ddd3,"Silent")

  print("Finished Solving for Droplet Transport")
  droplet1_data <- as_tibble(droplet_1) %>%
    mutate(Droplet = "Centerline",
           ColorSet = "#ffd700")
  droplet2_data <- as_tibble(droplet_2) %>%
    mutate(Droplet = "Downwind",
           ColorSet = "#00ffd7")
  droplet3_data <- as_tibble(droplet_3) %>%
    mutate(Droplet = "Upwind",
           ColorSet = "#d700ff")

  All_droplet_data <- rbind(droplet1_data,
                            droplet2_data,
                            droplet3_data)

  droplet_plot <- ggplot(All_droplet_data, aes(x = Xdist, y = Dp.1.23., color = Droplet)) +
    geom_point(size = 3, alpha = 0.5) +
    scale_color_manual(values = c("#ffd700", "#00ffd7", "#d700ff")) +
    ylab("Initial Droplet Diameter (microns)") +
    xlab("Distance Traveled to Depositions from Nozzle Centerline (ft)") +
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

  results$droplet_plot <- droplet_plot
  names(All_droplet_data)[1:3] <- c("Droplet_diameter","Distance_traveled","Droplet")


  results$All_droplet_data <- All_droplet_data
  # Part 5
  # ________________________________________
  a<-unname(pars$res)  # Calibration from step #1 (removing the stored names)

  # Input from previous function
  Cent<-droplet_1[2]$Xdist
  Dwnd<-droplet_2[2]$Xdist
  Uwnd<-droplet_3[2]$Xdist

  deposition<-deposition_calcs(IAR,xactive,FD,PL, NozzleSpacing, psipsipsi,rhoL, Cent,Dwnd,Uwnd, Dpmax, DDpmin,a,MMM, lambda,"Silent")
  results$deposition <- deposition

  return(results)
}
