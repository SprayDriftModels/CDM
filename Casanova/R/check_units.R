check_units <- function(paramsUnits, paramsData, driver) {

  shiny_check <- "PASS"

  if (paramsUnits %in% c("Metric", "metric")) {
    if (!(all(
      as.character(paramsData$Units) == Casanova::params_metric$Units,
      na.rm = T
    ))) {
      if (driver != "shiny") {
        stop(
          paste0(
            'Check units for Scenario_ID: ',
            i_scn,
            '. ',
            'Units should be ',
            paramsUnits,
            '. ',
            'See Casanova::params_metric for expected units for each parameter.'
          )
        )
      } else {
        shiny_check <- "FAIL"
      }
    }
  } else if (paramsUnits %in% c("English", "english")) {
    if (!(all(
      as.character(paramsData$Units) == Casanova::params_english$Units,
      na.rm = T
    ))) {
      if (driver != "shiny") {
        stop(
          paste0(
            'Check units for Scenario_ID: ',
            i_scn,
            '. ',
            'Units should be ',
            paramsUnits,
            '. ',
            'See Casanova::params_english for expected units for each parameter.'
          )
        )
      } else {
        shiny_check <- "Fail"
      }
    }

  }
  return(shiny_check)
}
