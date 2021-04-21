#' Run Casanova
#'
#' @param scnFile a csv file containing the DSD, Params, Param type and param ID used for the analysis; default file is Scenarios.csv
#' @param DDDParamsFile DDD parameter file; default file is DDD_Params.csv
#' @param report_folder is the folder to save the .html reports
#' @param report is a T/F input indicating whether reports need to be printed out
#' @param curvefitDSD is a T/F indicating whether the DSD will be curve fitted or interpolated
#' @param driver can be "text", "silent", "shiny" to output progress of step 5, no progress or progress for the shiny app respectively
#' @param curve_fit_ini_file is the file name with initial curve fit values; default file is Curve_Fit_Initial_Values.csv
#'
#' @return a list containing all droplet data and deposition for each scenario analyzed
#' @export
#'
#' @examples
runCasanova <- function(scnFile = "./sample_data/Scenarios.csv",
                        DDDparamsFile = "./sample_data/DDD_Params.csv",
                        report_folder = "./sample_data/reports",
                        curve_fit_ini_file = "./sample_data/Curve_Fit_Initial_Values.csv",
                        report = T,
                        curvefitDSD = F,
                        driver = "text") {

  results <- NULL
  all_results<- NULL

  # Start the clock
  ptm <- proc.time()

  ##############################################################################
  # See if the report output folder exists
  if (report){
    if (file.exists(report_folder)){
      rep_over<-readline(prompt=paste('The report folder',report_folder,'already exists. Overwrite files in folder? (Y/N)'))
      if (rep_over=='N'|rep_over=='n'){
        stop('Casanova run stopped to avoid overwriting output reports.')
      }
      else if (rep_over!='Y'&rep_over!='y'){
        stop('Please provide a valide Y/N response.')
      }
    }
  }

  # Read all the input files; error control if files cannot be read
  # Read scenario file
  scnData <- NULL
  if (driver %in% c("text", "silent")) {
    scnData <- tryCatch({
      read_csv(scnFile, col_types = 'icccic')
    },
    error = function(e) {
      print("Could not read scenario File")
    })
  } else if(driver == "shiny") {
    #***SFR check list of scnData
  }

  # Read DDDParameters file
  DDDparamsData <- NULL
  if (driver %in% c("text", "silent")) {
    DDDparamsData <- tryCatch({
      read_csv(DDDparamsFile, col_types = 'ddd')
    },
    error = function(e) {
      print("Could not read parameters File")
    })
  } else if (driver == "shiny") {
    DDDparamsData <- scnFile$DDDparamsData
  }

  # Read Curve_Fit_Initial_Values file
  CFiniData <- NULL
  if (driver %in% c("text", "silent")) {
    CFiniData <- tryCatch({
      read_csv(curve_fit_ini_file, col_types = 'ddddd')
    },
    error = function(e) {
      print("Could not read DSD Curve-fitting initial value File")
    })
  } else if (driver == "shiny") {
    CFiniData <- curve_fit_ini_file #this is uploaded as a dataset directly in case we allow users to select a different file (or could add to scnFile list if desired)
  }

  # Check the number of scenarios to be input sequentially
  if (driver %in% c("text", "silent")) {
    if (max(scnData$'Scenario_ID') == nrow(scnData)) {
      i_scn <- max(scnData$Scenario_ID)
    } else{
      stop('Please check the numbering of your scenarios')
    }

    if (i_scn > 1) {
      for (i in 2:i_scn) {
        if (scnData$'Scenario_ID'[i] - scnData$Scenario_ID[i - 1] != 1)
          (stop('Scenarios should be numbered sequentially'))
      }
    }
  }

  # The following files are read to test whether they can be read without errors
  if (driver == "shiny") i_scn <- 1

  for (i in 1:i_scn) {

    if (driver %in% c("text", "silent")) {
      # Read DSD file
      DSDFile <- paste0("./sample_data/", scnData$DSD_Filename[i])
      DSDData <- NULL
      DSDData <- tryCatch({
        read_csv(DSDFile, col_types = 'dddd')
      },
      error = function(e) {
        print(paste("Could not read DSD File for scenario", i))
      })

      # Read Parameters file
      paramsFile <-
        paste0("./sample_data/", scnData$Params_Filename[i])
      paramsData <- NULL
      paramsData <- tryCatch({
        #first need to know how many value columns there are
        temp <- read_csv(paramsFile)
        n_value_cols <- ncol(temp) - 3
        col_types_i <- paste0("ccc", strrep("d",n_value_cols))
        read_csv(paramsFile, col_types = col_types_i)
      },
      error = function(e) {
        print(paste("Could not read parameters File for scenario", i))
      })

    # browser()
    # Check the number of parameters to be input sequentially
    if (ncol(paramsData[which(paramsData$Type == 'ID'), ]) > 4) {
      for (j in 5:ncol(paramsData[which(paramsData$Type == 'ID'), ])) {
        if ((as.double(paramsData[which(paramsData$Type == 'ID'), ][j]) - as.double(paramsData[which(paramsData$Type ==
                                                                                                     'ID'), ][j - 1])) != 1) {
          stop('Parameter IDs should be numbered sequentially')
        }
      }
    }

    } else if (driver == "shiny") {
      DSDData <- scnFile$DSDData
      paramsData <- scnFile$paramsData
    }

    if (driver %in% c("text", "silent")) {
      paramsUnits <-
        scnData$Params_Units[i] # This is the unit system of the input parameters
      paramsID <-
        scnData$Params_ID[i] # This is the unit ID of the input parameters
    } else if (driver == "shiny") {
      paramsUnits <- scnFile$Params_Units
      paramsID <- scnFile$Params_ID
    }

    # Read Wind/Temp file if more than 1 measurement
    # measurements <- as.double(paramsData[which(paramsData$Type=='measurements'),][paramsID+3]) # Number of wind vs. height sets of measurements
    # if (measurements > 1) {
    #   # In this case the Wind/Temperature file is needed:
    #   paramsWTFile <-
    #     paste0("./sample_data/", scnData$Wind_Temp_Filename[i])
    #   paramsWT<-NULL
    #   paramsWT <- tryCatch({
    #     read_csv(paramsWTFile,col_types='dddd')
    #   },
    #   error=function(e){
    #     print("Could not read wind/temperature File")
    #   }
    #   )
    # } else {
    #   paramsWT <- NULL
    # }
    # Assign variable for Wind/Temperature file
    # paramsWTFile <-
    #   paste0("./sample_data/", scnData$Wind_Temp_Filename[i])

    # Read paramsWT
    paramsWT <- NULL
    if (driver %in% c("text", "silent")) {
      paramsWTFile <-
        paste0("./sample_data/", scnData$Wind_Temp_Filename[i])
      paramsWT <- tryCatch({
        read_csv(paramsWTFile,col_types='dddd')
      },
      error=function(e){
        print("Could not read wind/temperature File")
      }
      )
    } else if (driver == "shiny") {
      paramsWT <- scnFile$paramsWT
    }


    #***SFR these aren't checked. Do we need to check correct names and proper order of these?
    # units_type<-c("ID", "Tair", "Patm", "RH", "ch","measurements",  "z1", "ux1",
    #               "psipsipsi", "psipsipsi_method", "rhow", "rhos", "xs0", "rhosoln", "H0", "hcm", "app_p",
    #               "angle", "IAR", "xactive", "FD", "PL", "NozzleSpacing", "MMM", "lambda")

    #browser()
    ## Check that the user has not changed the default units:
    check_units(paramsUnits, paramsData, driver)


    #***SFR Need to also check units of paramsWT match params AND MAYBE that paramsWT column names are correct (or at least start with correct prefix, zw, u, zt, T )

    # paramsUnits<-scnData$`Params-Units`[i] # This is the unit system of the input parameters
    # paramsID<-scnData$`Params-ID`[i] # This is the unit ID of the input parameters

    # Try to assign parameters from loaded files
    #***SFR is this just a check? should there be a tryCatch for this?
    Casanova::inputs_from_csv(DSDData,
                              paramsData,
                              DDDparamsData,
                              paramsID,
                              paramsUnits,
                              paramsWT)
  }

  print("Able to read successfully input files; continuing to run the prescribed scenarios")

  ############################################################################
  # Loop all scenarios
  for (i in 1:i_scn) {
    # Error control if a scenario fails
    tryCatch({

      if (driver %in% c("text", "silent")) {
      # Read DSD file
      DSDFile<-paste0("./sample_data/",scnData$`DSD_Filename`[i])
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
      paramsFile<-paste0("./sample_data/",scnData$`Params_Filename`[i])
      paramsData<-NULL
      paramsData <- tryCatch({
        #first need to know how many value columns there are
        temp <- read_csv(paramsFile)
        n_value_cols <- ncol(temp) - 3
        col_types_i <- paste0("ccc", strrep("d",n_value_cols))
        read_csv(paramsFile,col_types = col_types_i)
      },
      error=function(e){
        print(paste("Could not read parameters File for scenario",i))
      }
      )
      paramsUnits<-scnData$`Params_Units`[i] # This is the unit system of the parameters
      paramsID<-scnData$`Params_ID`[i] # This is the unit system of the parameters

      # Read paramsWT
      paramsWT <- NULL
      paramsWTFile <-
        paste0("./sample_data/", scnData$Wind_Temp_Filename[i])
      paramsWT <- tryCatch({
        read_csv(paramsWTFile, col_types = 'dddd')
      },
      error = function(e) {
        print("Could not read wind/temperature File")
      })
    }


      # Finished reading input files

      # Assign parameters from loaded files
      all_inputs <- inputs_from_csv(DSDData,
                                    paramsData,
                                    DDDparamsData,
                                    paramsID,
                                    paramsUnits,
                                    paramsWT)

      # The following assigns the inputs converted to the computational units
      y <- all_inputs$input_props_comp$y
      Dpdata <- all_inputs$input_props_comp$Dpdata
      Tair <- all_inputs$input_props_comp$Tair
      Patm <- all_inputs$input_props_comp$Patm
      RH <- all_inputs$input_props_comp$RH
      measurements <- all_inputs$input_props_comp$measurements
      ch <- all_inputs$input_props_comp$ch
      z1 <- all_inputs$input_props_comp$z1
      ux1 <- all_inputs$input_props_comp$ux1
      rhow <- all_inputs$input_props_comp$rhow
      rhos <- all_inputs$input_props_comp$rhos
      xs0 <- all_inputs$input_props_comp$xs0
      rhosoln <- all_inputs$input_props_comp$rhosoln
      H0 <- all_inputs$input_props_comp$H0
      hcm <- all_inputs$input_props_comp$hcm
      app_p <- all_inputs$input_props_comp$app_p
      angle <- all_inputs$input_props_comp$angle
      ddd1 <- all_inputs$input_props_comp$ddd1
      ddd2 <- all_inputs$input_props_comp$ddd2
      ddd3 <- all_inputs$input_props_comp$ddd3
      IAR <- all_inputs$input_props_comp$IAR
      xactive <- all_inputs$input_props_comp$xactive
      FD <- all_inputs$input_props_comp$FD
      PL <- all_inputs$input_props_comp$PL
      NozzleSpacing <- all_inputs$input_props_comp$NozzleSpacing
      psipsipsi <- all_inputs$input_props_comp$psipsipsi
      rhoL <- all_inputs$input_props_comp$rhoL
      Dpmax <- all_inputs$input_props_comp$Dpmax
      DDpmin <- all_inputs$input_props_comp$DDpmin
      MMM <- all_inputs$input_props_comp$MMM
      lambda <- all_inputs$input_props_comp$lambda
      paramsWT <- all_inputs$input_props_comp$paramsWT
      method <- all_inputs$input_props_comp$method


      #browser()

      if (curvefitDSD == T) {
        # Part 1, Curve fitting: Variable pars contains the fitted parameters of the drop size distribution model
        pars <- psd(y, Dpdata, CFiniData)
        results$psd_pars <- pars
      } else {
        results$psd_pars <- list(
          "res" = 'No DSD fitting',
          "plot" = 'No DSD fitting',
          "table" = 'No DSD fitting',
          "y" = y,
          "Dpdata" = Dpdata
        )
      }

      results$psd_stats<-psd_stats(y,Dpdata)


      # browser()
      # Part 2, Wet Bulb Calculations
      Twb <- wet_bulb(Tair, Patm, RH)
      results$Twb <- Twb

      #browser()

      # Part 3, Wind profile and turbulence (psipsipsi) parameters
      measurements <- paramsWT %>% select(c(1)) %>% na.omit() %>% nrow() %>% as.integer()
      if (measurements == 1) {
        # This first part is when we have only one wind v. elevation measurement.
        # Outputs are Uh, Ufriction, z1, z0, alpha_avg, k2

        profile <- wvprofile(z1, ux1, ch)
        z0 <- profile[1]
        Uf <- profile[2]

        wvprofile_params <- profile

      } else if (measurements > 1) {

        z0 <- wvprofilem(paramsWT, method, ch)[1]
        Uf <- wvprofilem(paramsWT, method, ch)[2]
        if (!is.nan(wvprofilem(paramsWT, method, ch)[3])) {
          psipsipsi<-wvprofilem(paramsWT, method, ch)[3]   # This calculation overrides the input psipsipsi if measurements are more than 1
        }

        wvprofile_params <- wvprofilem(paramsWT, method, ch)
      }
      results$wvprofile_params <- wvprofile_params
      # browser()

      #Part 4, Droplet Transport Calculations
      tryCatch({
        charac<-charact_cal(app_p, angle, rhosoln)
        #browser()

        DTwb<-Twb[1] # Wetbulb temperature depression, C

        # Increment the progress bar, and update the detail text
        # if (driver %in% c("text", "silent")) {
            print(paste("Solving Straight Down Problem for Scenario", i))
        if (driver == "shiny") {
        incProgress(1/6, detail = paste0("Solving Straight Down Problem"))
        }
        #browser()


        droplet_1 <-
          Casanova::droplet_transport(Tair,
                                      RH,
                                      rhow,
                                      rhos,
                                      xs0,
                                      H0,
                                      DTwb,
                                      hcm,
                                      Uf,
                                      z0,
                                      app_p,
                                      charac[1],
                                      charac[2],
                                      ddd1,
                                      driver)
        ## Progress update
        # if (driver %in% c("text", "silent")) {
          print(paste("Solving with Wind Problem for Scenario", i))
        if (driver == "shiny") {
        incProgress(1/6, detail = paste0("Solving with Wind Problem"))
        }

        droplet_2 <-
          Casanova::droplet_transport(Tair,
                                      RH,
                                      rhow,
                                      rhos,
                                      xs0,
                                      H0,
                                      DTwb,
                                      hcm,
                                      Uf,
                                      z0,
                                      app_p,
                                      charac[3],
                                      charac[4],
                                      ddd2,
                                      driver)

        ## Progress update
        # if (driver %in% c("text", "silent")) {
          print(paste("Solving against Wind Problem for Scenario", i))
        if (driver == "shiny") {
        incProgress(1/6, detail = paste0("Solving against Wind Problem"))
        }

        droplet_3 <-
          Casanova::droplet_transport(Tair,
                                      RH,
                                      rhow,
                                      rhos,
                                      xs0,
                                      H0,
                                      DTwb,
                                      hcm,
                                      Uf,
                                      z0,
                                      app_p,
                                      charac[5],
                                      charac[6],
                                      ddd3,
                                      driver)

        ## Progress update
        # if (driver %in% c("text", "silent")) {
          print(paste("Finished Solving for Droplet Transport for Scenario", i))
        if (driver == "shiny") {
        incProgress(1/6, detail = paste0("Finished Solving for Droplet Transport"))
        }

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

      error = function(e) {
        "Could not run part 4, Droplet Transfer Function"
      }
      )

      # Part 5
      # ________________________________________

      if (curvefitDSD == T) {
        a <- unname(pars$res)  # Calibration from step #1 (removing the stored names)
      } else {
        a <- NULL
      }
      # Input from previous function
      Cent <- droplet_1[2]$Xdist
      Dwnd <- droplet_2[2]$Xdist
      Uwnd <- droplet_3[2]$Xdist

      tryCatch({
        # browser()
        ## Progress update
        # if (driver %in% c("text", "silent")) {
        print(paste("Calculating Deposition for Scenario", i))
        if (driver == "shiny") {
          incProgress(1/6, detail = paste0("Calculating Deposition"))
        }

        deposition <-
          deposition_calcs(
            IAR,
            xactive,
            FD,
            PL,
            NozzleSpacing,
            psipsipsi,
            rhoL,
            Cent,
            Dwnd,
            Uwnd,
            Dpmax,
            DDpmin,
            a,
            MMM,
            lambda,
            driver,
            curvefitDSD,
            y,
            Dpdata
          )
        # if (driver %in% c("text", "silent")) {
        print(paste("Deposition calculations are finished for Scenario", i))
        if (driver == "shiny") {
          incProgress(1/6, detail = paste0("Deposition calculations finished"))
        }
      },
      error = function(e) {
        print("Could not run part 5, Deposition Calculations")
      })
      results$deposition <- deposition
    },
    error = function(e) {
      print(paste("Could not run scenario", i))
    }
    )
#browser()
    # The following generates one .html report per scenario
    if (report == T) {
      write_report(i, all_inputs, results, report_folder, paramsUnits, driver, Scenario_ID = i, paramsWT)
    }

    all_results[[i]] <-
      results # This list stores all results so that they can be output

  }  # This is the end of the loop for all scenarios

  try(dev.off(), silent = T)
  # This prevents a bug that causes Rstudio to crash sometimes if one accesses the plots from the return value
  print(paste('Computation time was:', (proc.time() - ptm)[[3]]))

  if (driver %in% c("text", "silent")) {
  return(all_results)
  } else if (driver == "shiny") {
    return(list(all_inputs = all_inputs,
                results = results,
                paramsUnits = paramsUnits))
  }


}
