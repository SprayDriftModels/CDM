#' Create html report for each scenario
#'
#' @param i Scenario
#' @param all_inputs list with all model inputs
#' @param results the results of the casanova model
#'
#' @return a list containing all input data
#' @export
#'
#' @examples
write_report <- function(i,
                         all_inputs,
                         results,
                         report_folder,
                         paramsUnits,
                         driver,
                         Scenario_ID,
                         paramsWT)

  {

  if (driver %in% c("text", "silent")) {
    filename = paste("Scenario", i,"report.html")
    dir.create(report_folder)
    template_rmd <- ('./R/report.Rmd')
  } else if (driver == "shiny") {
    template_rmd <- ('../R/report.Rmd')
    filename = report_folder
  }


  ## Set up parameters to pass to Rmd document
  # Create table of parameters used

  # replace NULL values with NA in all_inputs
  if (is.null(all_inputs$input_props$z1)){all_inputs$input_props$z1<-NA}
  if (is.null(all_inputs$input_props$ux1)){all_inputs$input_props$ux1<-NA}
  psipsipsi_rep<-all_inputs$input_props$psipsipsi

  wm<-all_inputs$input_props$measurements
  if (wm!=1){
    wm<-NA
    psipsipsi_rep<-NA
    }

  #browser()
  input_params <- tibble("Dry air temperature" = all_inputs$input_props$Tair,
                         "Barometric pressure" = all_inputs$input_props$Patm,
                         "Relative humidity" = all_inputs$input_props$RH,
                         # "Number of wind measurements" = wm,
                         # "Elevation of wind speed (1)" = psipsipsi_rep,
                         # "MPH wind speed (1)" = all_inputs$input_props$ux1,
                         "Density of pure water in droplet" = all_inputs$input_props$rhow,
                         "Density of dissolved solids in droplet" = all_inputs$input_props$rhos,
                         "Mass fraction total dissolved solids in solution" = all_inputs$input_props$xs0,
                         "Height of nozzle above ground" = all_inputs$input_props$H0,
                         "Canopy height (Droplet Transport Calculation)" = all_inputs$input_props$hcm,
                         "Nozzle pressure" = all_inputs$input_props$app_p,
                         "Nozzle angle" = all_inputs$input_props$angle,
                         "Mix density" = all_inputs$input_props$rhosoln,
                         "Intended Application Rate" = all_inputs$input_props$IAR,
                         "Conc in tank solution" = all_inputs$input_props$xactive,
                         "Downwind field depth" = all_inputs$input_props$FD,
                         "Crosswind field width" = all_inputs$input_props$PL,
                         "Space between nozzles on Boom" = all_inputs$input_props$NozzleSpacing,
                         "Horizontal variation in wind direction around mean direction, 1 stdev" = psipsipsi_rep,
                         "Dpmax" = all_inputs$input_props$Dpmax,
                         "Dpmin" = all_inputs$input_props$DDpmin,
                         "Number of droplet size bins" = all_inputs$input_props$MMM,
                         "Resolution of deposition calculations" = all_inputs$input_props$lambda
  ) %>%
  pivot_longer(everything(),
               names_to = "Parameters",
               values_to = "Value")



  # #*** add sort to each of these after pivot
  # if(all_inputs[[1]][[6]] == 1){
  #   input_params <- input_params %>%
  #     mutate("Canopy height" = all_inputs[[1]][[7]]) %>%
  #     pivot_longer(everything(),
  #                  names_to = "Parameters",
  #                  values_to = "Value")
  #     # wvprofile_params <- wvprofile(all_inputs[[1]][[8]],
  #     #                               all_inputs[[1]][[9]],
  #     #                               all_inputs[[1]][[7]])
  # }
  #
  # if(all_inputs[[1]][[6]] == 2){
  #   input_params <- input_params %>%
  #     mutate("Elevation of wind speed (2)" = all_inputs[[1]][[10]],
  #            "MPH wind speed (2)" = all_inputs[[1]][[11]]) %>%
  #     pivot_longer(everything(),
  #                  names_to = "Parameters",
  #                  values_to = "Value")
  #     # wvprofile_params <- WV2m(all_inputs[[1]][[8]],
  #     #                          all_inputs[[1]][[10]],
  #     #                          all_inputs[[1]][[7]],
  #     #                          all_inputs[[1]][[11]])
  # }


  if (paramsUnits=='English'){
  param_units <- tibble("Dry air temperature" = "Farhenheit",
                        "Barometric pressure" = "mmHg abs",
                        "Relative humidity" = "%",
                        # "Number of wind measurements" = "NA",
                        # "Elevation of wind speed (1)" = "ft",
                        # "MPH wind speed (1)" = "mph",
                        "Density of pure water in droplet" = "lbs/ft3",
                        "Density of dissolved solids in droplet" = "lbs/ft3",
                        "Mass fraction total dissolved solids in solution" = "NA",
                        "Height of nozzle above ground" = "in",
                        "Canopy height" = "in",
                        "Nozzle pressure" = "psi",
                        "Nozzle angle" = "degrees",
                        "Mix density" = "lbs/ft3",
                        "Intended Application Rate" = "lb/acre",
                        "Conc in tank solution" = "wtfraction",
                        "Downwind field depth" = "ft",
                        "Crosswind field width" = "ft",
                        "Space between nozzles on Boom" = "in",
                        "Horizontal variation in wind direction around mean direction, 1 stdev" = "degrees",
                        "Dpmax" = "µm",
                        "Dpmin" = "µm",
                        "Number of droplet size bins" = "MMM",
                        "Resolution of deposition calculations" = "NA"
  ) %>%
    pivot_longer(everything(),
                 names_to = "Parameters",
                 values_to = "Units")
  }
  else if (paramsUnits=='Metric'){
    param_units <- tibble("Dry air temperature" = "Celcius",
                          "Barometric pressure" = "mmHg abs",
                          "Relative humidity" = "%",
                          # "Number of wind measurements" = "NA",
                          #"Elevation of wind speed (1)" = "m",
                          #"MPH wind speed (1)" = "m/s",
                          "Density of pure water in droplet" = "g/cm3",
                          "Density of dissolved solids in droplet" = "g/cm3",
                          "Mass fraction total dissolved solids in solution" = "NA",
                          "Height of nozzle above ground" = "cm",
                          "Canopy height" = "cm",
                          "Nozzle pressure" = "kPa",
                          "Nozzle angle" = "degrees",
                          "Mix density" = "kg/m3",
                          "Intended Application Rate" = "kg/ha",
                          "Conc in tank solution" = "wtfraction",
                          "Downwind field depth" = "m",
                          "Crosswind field width" = "m",
                          "Space between nozzles on Boom" = "cm",
                          "Horizontal variation in wind direction around mean direction, 1 stdev" = "degrees",
                          "Dpmax" = "µm",
                          "Dpmin" = "µm",
                          "Number of droplet size bins" = "MMM",
                          "Resolution of deposition calculations" = "NA"
    ) %>%
      pivot_longer(everything(),
                   names_to = "Parameters",
                   values_to = "Units")
  }

  #browser()

  input_params_units <- left_join(x = input_params,
                                  y = param_units,
                                  by = "Parameters")


  # Need to edits this one: XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXs
  params <- list(#input_filename = "Superceded code",
                 input_scenarioID = Scenario_ID,
                 input_params = input_params_units,
                 step1_results_plot = results$psd_pars$plot,
                 step1_results_table = results$psd_pars$table,
                 step1_results_stats = results$psd_stats,
                 step2_results = results$Twb,
                 step3_results = results$wvprofile_params,
                 step4_results = results$All_droplet_data,
                 step5_results = results$deposition,
                 input_paramsWT = paramsWT
  )

  # Knit the document, passing in the `params` list, and eval it in a
  # child of the global environment (this isolates the code in the document
  # from the code in this app).
  rmarkdown::render(template_rmd,
                    output_file = filename,
                    output_dir = report_folder,
                    params = params,
                    envir = new.env(parent = globalenv()),
                    quiet=T
  )
}


