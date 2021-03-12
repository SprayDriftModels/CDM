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
                         report_folder)

  {
  # For PDF output, change this to "report.pdf"
  filename = paste("Scenario",i,"report.html")
  dir.create(report_folder)
  # Copy the report file to a temporary directory before processing it, in
  # case we don't have write permissions to the current working dir (which
  # can happen when deployed).
  #tempReport <- file.path(tempdir(), "\\report.Rmd")
  tempReport <- ('./R/report.Rmd')
  file.copy("report.Rmd", tempReport, overwrite = TRUE)

  ## Set up parameters to pass to Rmd document
  # Create table of parameters used


  input_params <- tibble("Dry air temperature" = all_inputs[[1]][[3]],
                         "Barometric pressure" = all_inputs[[1]][[4]],
                         "Relative humidity" = all_inputs[[1]][[5]],

                         "Number of wind measurements" = all_inputs[[1]][[6]],
                         "Elevation of wind speed (1)" = all_inputs[[1]][[8]],
                         "MPH wind speed (1)" = all_inputs[[1]][[9]],

                         "Density of pure water in droplet" = all_inputs[[1]][[12]],
                         "Density of dissolved solids in droplet" = all_inputs[[1]][[13]],
                         "Mass fraction total dissolved solids in solution" = all_inputs[[1]][[14]],
                         "Height of nozzle above ground" = all_inputs[[1]][[16]],
                         "Canopy height (Droplet Transport Calculation)" = all_inputs[[1]][[17]],
                         "Nozzle pressure" = all_inputs[[1]][[18]],
                         "Nozzle angle" = all_inputs[[1]][[19]],
                         "Mix density" = all_inputs[[1]][[15]],

                         "Intended Application Rate" = all_inputs[[1]][[23]],
                         "Conc in tank solution" = all_inputs[[1]][[24]],
                         "Downwind field depth" = all_inputs[[1]][[25]],
                         "Crosswind field width" = all_inputs[[1]][[26]],
                         "Space between nozzles on Boom" = all_inputs[[1]][[27]],
                         "Horizontal variation in wind direction around mean direction, 1 stdev" = all_inputs[[1]][[28]],
                         "Dpmax" = all_inputs[[1]][[30]],
                         "Dpmin" = all_inputs[[1]][[31]],
                         "Number of droplet size bins" = all_inputs[[1]][[32]],
                         "Resolution of deposition calculations" = all_inputs[[1]][[33]]
  )

  #*** add sort to each of these after pivot
  if(all_inputs[[1]][[6]] == 1){
    input_params <- input_params %>%
      mutate("Canopy height" = all_inputs[[1]][[7]]) %>%
      pivot_longer(everything(),
                   names_to = "Parameters",
                   values_to = "Value")
      # wvprofile_params <- wvprofile(all_inputs[[1]][[8]],
      #                               all_inputs[[1]][[9]],
      #                               all_inputs[[1]][[7]])
  }

  if(all_inputs[[1]][[6]] == 2){
    input_params <- input_params %>%
      mutate("Elevation of wind speed (2)" = all_inputs[[1]][[10]],
             "MPH wind speed (2)" = all_inputs[[1]][[11]]) %>%
      pivot_longer(everything(),
                   names_to = "Parameters",
                   values_to = "Value")
      # wvprofile_params <- WV2m(all_inputs[[1]][[8]],
      #                          all_inputs[[1]][[10]],
      #                          all_inputs[[1]][[7]],
      #                          all_inputs[[1]][[11]])
  }


  param_units <- tibble("Dry air temperature" = "Farheneit",
                        "Barometric pressure" = "mmHg abs",
                        "Relative humidity" = "%",
                        "Number of wind measurements" = "NA",
                        "Elevation of wind speed (1)" = "ft",
                        "MPH wind speed (1)" = "mph",
                        "Elevation of wind speed (2)" = "ft",
                        "MPH wind speed (2)" = "mph",
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


  input_params_units <- left_join(x = input_params,
                                  y = param_units,
                                  by = "Parameters")


  # Need to edits this one: XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXs
  params <- list(input_filename = "Superceded code",
                 input_params = input_params_units,
                 step1_results_plot = results$psd_pars$plot,
                 step1_results_table = results$psd_pars$table,
                 step2_results = results$Twb,
                 step3_results = results$wvprofile_params,
                 step4_results = results$All_droplet_data,
                 step5_results = results$deposition
  )

  # Knit the document, passing in the `params` list, and eval it in a
  # child of the global environment (this isolates the code in the document
  # from the code in this app).
  rmarkdown::render(tempReport, output_file = filename, output_dir=report_folder,
                    params = params,
                    envir = new.env(parent = globalenv()),
                    quiet=T
  )
}


