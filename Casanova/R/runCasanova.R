#' Run Casanova
#'
#' @param scnFile a csv file containing the DSD, Params, Param type and param ID used for the analysis; default file is Scenarios.csv
#' @param DSDFile a csv file defining the DSD measurements; the function takes the average of each trial
#' @param paramsFile a csv file defining all the inputs; default file is Params (Metric) for metric
#' @param DDDParamsFile DDD parameter file; default file is DDD_Params.csv
#' @param report is a T/F input indicating whether reports need to be printed out
#'
#' @return a list containing all droplet data and deposition for each scenario analyzed
#' @export
#'
#' @examples
runCasanova <- function(scnFile="./sample_data/Scenarios.csv",
                        paramsFile="./sample_data/Params (Metric).csv",
                        DDDParamsFile="./sample_data/DDD_Params.csv",
                        report=F){
  results <- NULL

  ##############################################################################
  # Read all the input files; error control if files cannot be read
  # Read scenario file
  scnData<-NULL
  scnData <- tryCatch({
    read_csv(scnFile)
  },
  error=function(e){
    "Could not read scenario File"
  }
  )

  # Read DDDParameters file
#  DDDparamsFile="./sample_data/DDD_Params.csv" # test line to be removed
  DDDparamsData<-NULL
  DDDparamsData <- tryCatch({
    read_csv(DDDparamsFile)
  },
  error=function(e){
    "Could not read parameters File"
  }
  )

  ############################################################################
  # Loop all scenarios
  i_scn<-max(scnData$'Scenario-ID')

  for (i in 1:i_scn) {
    # Error control is a scenario fails
    tryCatch({
      # Read DSD file
      DSDFile<-paste0("./sample_data/",scnData$`DSD-Filename`[i])
      DSDData<-NULL
      DSDData <- tryCatch({
        read_csv(DSDFile)
      },
      error=function(e){
        "Could not read DSD File"
      }
      )

      # Read Parameters file
      paramsFile<-paste0("./sample_data/",scnData$`Params-Filename`[i])
      paramsData<-NULL
      paramsData <- tryCatch({
        read_csv(paramsFile)
      },
      error=function(e){
        "Could not read parameters File"
      }
      )

      paramsType<-scnData$`Params-Type`[i] # This is the unit system of the parameters
      paramsID<-scnData$`Params-ID`[i] # This is the unit system of the parameters

      ## Load hard-coded inputs
      # AV comment: I think p and NF were not used after all in calculations
      #Nozzle_params <- as_tibble(read.csv(NozzleParamFile, header = T))
      #p <- Nozzle_params %>% select(p)
      #NF <- Nozzle_params %>% select(NF)

      # Finished reading input files

      # Assign parameters from loaded files
      source("inputs_from_csv.R")

      # Part 1, Curve fitting: Variable pars contains the fitted parameters of the drop size distribution model
      pars <- psd(y,Dpdata)

      # Part 2, Wet Bulb Calculations
      Twb <- wet_bulb(Tair, Patm, RH)
      wv <- WV2m (z1=z1, z2, ux1, ux2)
      z0 <- wv[1]
      Uf <- wv[2]

      #Part 4, Droplet Transport Calculations
      tryCatch({
        charac<-charact_cal(app_p,angle, rhosoln)
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


        # Store results for function output
        results$droplet_plot <- droplet_plot
        names(All_droplet_data)[1:3] <- c("Droplet_diameter","Distance_traveled","Droplet")
        results$All_droplet_data <- All_droplet_data

      },

      error=function(e){
        "Could not run part 4, Droplet Transfer Function"
        ############################NEED To add results
      }
      )

      # Part 5
      # ________________________________________
      a<-unname(pars$res)  # Calibration from step #1 (removing the stored names)

      # Input from previous function
      Cent<-droplet_1[2]$Xdist
      Dwnd<-droplet_2[2]$Xdist
      Uwnd<-droplet_3[2]$Xdist

      tryCatch(
        {
          deposition<-deposition_calcs(IAR,xactive,FD,PL, NozzleSpacing, psipsipsi,rhoL, Cent,Dwnd,Uwnd, Dpmax, DDpmin,a,MMM, lambda,"Silent")
        },
        error=function(e){
          "Could not run part 5, Deposition Calculations"
        }

      )
      results$deposition <- deposition


    },
    error=function(e){
      paste("Could not run scenario",i)
    }

    )


  }  # This is the end of the loop for all scenario being

  all_results[[i]]<-results # This list stores all results so that they can be output
  return(all_results)
}
