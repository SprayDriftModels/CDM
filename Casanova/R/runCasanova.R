#' Run Casanova
#'
#' @param scnFile a csv file containing the DSD, Params, Param type and param ID used for the analysis; default file is Scenarios.csv
#' @param DDDParamsFile DDD parameter file; default file is DDD_Params.csv
#' @param report_folder is the folder to save the .html reports
#' @param report is a T/F input indicating whether reports need to be printed out
#' @param curvefitDSD is a T/F indicating whether the DSD will be curve fitted or interpolated
#'
#' @return a list containing all droplet data and deposition for each scenario analyzed
#' @export
#'
#' @examples
runCasanova <- function(scnFile="./sample_data/Scenarios.csv",
                        DDDparamsFile="./sample_data/DDD_Params.csv",
                        report_folder="./sample_data/reports",
                        report=T,
                        curvefitDSD=F){
  results <- NULL
  all_results<- NULL

  # Start the clock
  ptm <- proc.time()

  ##############################################################################
  # Read all the input files; error control if files cannot be read
  # Read scenario file
  scnData<-NULL
  scnData <- tryCatch({
    read_csv(scnFile,col_types='iccci')
  },
  error=function(e){
    print("Could not read scenario File")
  }
  )

  # Read DDDParameters file
  DDDparamsData<-NULL
  DDDparamsData <- tryCatch({
    read_csv(DDDparamsFile,col_types='ddd')
  },
  error=function(e){
    print("Could not read parameters File")
  }
  )

  # The following files are read to test whether they can be read without errors

  # Check the number of scenarios to be input sequentially
  if(max(scnData$'Scenario-ID')==nrow(scnData)) {
    i_scn<-max(scnData$'Scenario-ID')
  }
  else{
    stop('Please check the numbering of your scenarios')
  }

  if (i_scn>1){
    for (i in 2:i_scn){
      if(scnData$'Scenario-ID'[i]-scnData$'Scenario-ID'[i-1]!=1)
      (stop('Scenarios should be numbered sequentially'))
    }
  }


  # The following files are read to test whether they can be read without errors
  for (i in 1:i_scn){
    # Read DSD file
    DSDFile<-paste0("./sample_data/",scnData$`DSD-Filename`[i])
    DSDData<-NULL
    DSDData <- tryCatch({
      read_csv(DSDFile,col_types='dddd')
    },
    error=function(e){
      print(paste("Could not read DSD File for scenario",i))
    }
    )

    # Read Parameters file
    paramsFile<-paste0("./sample_data/",scnData$`Params-Filename`[i])
    paramsData<-NULL
    paramsData <- tryCatch({
      read_csv(paramsFile,col_types='cccddddddddddddd')
    },
    error=function(e){
      print(paste("Could not read parameters File for scenario",i))
    }
    )

    # browser()
    # Check the number of parameters to be input sequentially
    if (ncol(paramsData[which(paramsData$Type=='ID'),])>4){
      for (j in 5:ncol(paramsData[which(paramsData$Type=='ID'),])){
        if ((as.double(paramsData[which(paramsData$Type=='ID'),][j])-as.double(paramsData[which(paramsData$Type=='ID'),][j-1]))!=1){
          stop('Parameter IDs should be numbered sequentially')
        }
      }
    }

    # Check that the user has not changed the default units:
    units_english<-c(NA, "Farheneit", "mmHg abs", "%", NA, "in", "ft", "mph", "ft",
                     "mph", "lbs/ft3", "lbs/ft3", NA, "lbs/ft3", "in", "in", "psi",
                     "degrees", "lb/acre", "wtfraction", "ft", "ft", "in", "degrees",
                     "microm", "microm", "#", NA)
    units_metric<-c(NA, "Celcius", "mmHg abs", "%", NA, "cm", "m", "m/s", "m",
                    "m/s", "g/cm3", "g/cm3", NA, "kg/m3", "cm", "cm", "kPa", "degrees",
                    "kg/ha", "wtfraction", "m", "m", "cm", "degrees", "microm", "microm",
                    "#", NA)

    units_type<-c("ID", "Tair", "Patm", "RH", "measurements", "ch", "z1", "ux1",
                  "z2", "ux2", "rhow", "rhos", "xs0", "rhosoln", "H0", "hcm", "app_p",
                  "angle", "IAR", "xactive", "FD", "PL", "NozzleSpacing", "psipsipsi",
                  "Dpmax", "Ddpmin", "MMM", "lambda")

    # browser()
    if (!(all(paramsData$Units==units_english,na.rm=T) | all(paramsData$Units==units_metric, na.rm=T) )){
      stop('Parameter units should either be in english',units_english, 'or metric', units_metric)

    }


    paramsUnits<-scnData$`Params-Units`[i] # This is the unit system of the input parameters
    paramsID<-scnData$`Params-ID`[i] # This is the unit ID of the input parameters

    # Try to assign parameters from loaded files
    inputs_from_csv(DSDData,
                    paramsData,
                    DDDparamsData,
                    paramsID,
                    paramsUnits)

  }

  print("Able to read successfully input files; continuing to run the prescribed scenarios")

  ############################################################################
  # Loop all scenarios
  for (i in 1:i_scn) {
    # Error control is a scenario fails
    tryCatch({
      # Read DSD file
      DSDFile<-paste0("./sample_data/",scnData$`DSD-Filename`[i])
      DSDData<-NULL
      DSDData <- tryCatch({
        read_csv(DSDFile,col_types='dddd')
      },
      error=function(e){
        print(paste("Could not read DSD File for scenario",i))
      }
      )
      # browser()
      # Read Parameters file
      paramsFile<-paste0("./sample_data/",scnData$`Params-Filename`[i])
      paramsData<-NULL
      paramsData <- tryCatch({
        read_csv(paramsFile,col_types='cccddddddddddddd')
      },
      error=function(e){
        print(paste("Could not read parameters File for scenario",i))
      }
      )
      paramsUnits<-scnData$`Params-Units`[i] # This is the unit system of the parameters
      paramsID<-scnData$`Params-ID`[i] # This is the unit system of the parameters

      ## Load hard-coded inputs
      # AV comment: I think p and NF were not used after all in calculations
      #Nozzle_params <- as_tibble(read.csv(NozzleParamFile, header = T))
      #p <- Nozzle_params %>% select(p)
      #NF <- Nozzle_params %>% select(NF)

      # Finished reading input files

      # Assign parameters from loaded files
      all_inputs<-inputs_from_csv(DSDData,
                                  paramsData,
                                  DDDparamsData,
                                  paramsID,
                                  paramsUnits)

      # The following assigns the inputs converted to the computational units
      y<-all_inputs[[2]][[1]]
      Dpdata<-all_inputs[[2]][[2]]
      Tair<-all_inputs[[2]][[3]]
      Patm<-all_inputs[[2]][[4]]
      RH<-all_inputs[[2]][[5]]
      measurements<-all_inputs[[2]][[6]]
      ch<-all_inputs[[2]][[7]]
      z1<-all_inputs[[2]][[8]]
      ux1<-all_inputs[[2]][[9]]
      z2<-all_inputs[[2]][[10]]
      ux2<-all_inputs[[2]][[11]]
      rhow<-all_inputs[[2]][[12]]
      rhos<-all_inputs[[2]][[13]]
      xs0<-all_inputs[[2]][[14]]
      rhosoln<-all_inputs[[2]][[15]]
      H0<-all_inputs[[2]][[16]]
      hcm<-all_inputs[[2]][[17]]
      app_p<-all_inputs[[2]][[18]]
      angle<-all_inputs[[2]][[19]]
      ddd1<-all_inputs[[2]][[20]]
      ddd2<-all_inputs[[2]][[21]]
      ddd3<-all_inputs[[2]][[22]]
      IAR<-all_inputs[[2]][[23]]
      xactive<-all_inputs[[2]][[24]]
      FD<-all_inputs[[2]][[25]]
      PL<-all_inputs[[2]][[26]]
      NozzleSpacing<-all_inputs[[2]][[27]]
      psipsipsi<-all_inputs[[2]][[28]]
      rhoL<-all_inputs[[2]][[29]]
      Dpmax<-all_inputs[[2]][[30]]
      DDpmin<-all_inputs[[2]][[31]]
      MMM<-all_inputs[[2]][[32]]
      lambda<-all_inputs[[2]][[33]]

      #browser()

      if (curvefitDSD==T){
        # Part 1, Curve fitting: Variable pars contains the fitted parameters of the drop size distribution model
        pars <- psd(y,Dpdata)
        results$psd_pars<-pars
      }
      else
      {
        results$psd_pars<-list("res" = 'No DSD fitting',
                               "plot" = 'No DSD fitting',
                               "table" = 'No DSD fitting',
                               "y" = y,
                               "Dpdata" = Dpdata)
      }

      #browser()
      # Part 2, Wet Bulb Calculations
      Twb <- wet_bulb(Tair, Patm, RH)
      results$Twb<-Twb

      # browser()

      # Part 3, Wind profile parameters
      if (measurements==1){
        # This first part is when we have only one wind v. elevation measurement.
        # Outputs are Uh, Ufriction, z1, z0, alpha_avg, k2

        profile<-wvprofile(z1, ux1, ch)
        z0<-profile[1]
        Uf<-profile[2]

        wvprofile_params <-profile

      }else if (measurements==2){
        # Part for when we have two wind v. elevation measurements.
        z0<-WV2m(z1,z2,ux1,ux2)[1]
        Uf<-WV2m(z1,z2,ux1,ux2)[2]
        wvprofile_params<-WV2m(z1,z2,ux1,ux2)
      }
      results$wvprofile_params<-wvprofile_params

      #Part 4, Droplet Transport Calculations
      tryCatch({
        charac<-charact_cal(app_p,angle, rhosoln)
        DTwb<-Twb[1] # Wetbulb temperature depression, C
        print(paste("Solving Straight Down Problem for Scenario", i))
        droplet_1<-droplet_transport(Tair,RH,rhow,rhos,xs0,H0,DTwb,hcm,Uf,z0,app_p,charac[1],charac[2],ddd1,"text")
        print(paste("Solving with Wind Problem for Scenario", i))
        droplet_2<-droplet_transport(Tair,RH,rhow,rhos,xs0,H0,DTwb,hcm,Uf,z0,app_p,charac[3],charac[4],ddd2,"text")
        print(paste("Solving against Wind Problem for Scenario", i))
        droplet_3<-droplet_transport(Tair,RH,rhow,rhos,xs0,H0,DTwb,hcm,Uf,z0,app_p,charac[5],charac[6],ddd3,"text")

        print(paste("Finished Solving for Droplet Transport for Scenario", i))

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
        # browser()
        names(All_droplet_data)[1:3] <- c("Droplet_diameter","Distance_traveled","Droplet")
        droplet_plot<-plot_droplet_data(All_droplet_data)

        # Store results for function output
        results$droplet_plot <- droplet_plot
        results$All_droplet_data <- All_droplet_data

      },

      error=function(e){
        "Could not run part 4, Droplet Transfer Function"
      }
      )

      # Part 5
      # ________________________________________

      if (curvefitDSD==T){
        a<-unname(pars$res)  # Calibration from step #1 (removing the stored names)
      }
      else {
        a<-NULL
      }
      # Input from previous function
      Cent<-droplet_1[2]$Xdist
      Dwnd<-droplet_2[2]$Xdist
      Uwnd<-droplet_3[2]$Xdist

      tryCatch(
        {
          #browser()
          print(paste("Calculating Deposition for Scenario", i))
          deposition<-deposition_calcs(IAR,xactive,FD,PL, NozzleSpacing, psipsipsi,rhoL, Cent,Dwnd,Uwnd, Dpmax, DDpmin,a,MMM, lambda,"Silent",curvefitDSD,y,Dpdata)
          print(paste("Deposition calculations are finished for Scenario", i))
        },
        error=function(e){
          print("Could not run part 5, Deposition Calculations")
        }

      )
      results$deposition <- deposition


    },
    error=function(e){
      print(paste("Could not run scenario",i))
    }

    )
browser()
    # The following generates one .html report per scenario
    if (report==T){
      write_report(i,all_inputs, results, report_folder)

    }

    all_results[[i]]<-results # This list stores all results so that they can be output

  }  # This is the end of the loop for all scenarios

  try(dev.off(),silent = T) # This prevents a bug that causes Rstudio to crash sometimes if one accesses the plots from the return value
  print(paste('Computation time was:', (proc.time() - ptm)[[3]]))
  return(all_results)
}
