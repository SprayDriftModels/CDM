#' The function to run the Casanova App
#' @export
#' @details https://deanattali.com/2015/04/21/r-package-shiny-app/ Also, to use private or company repositiories,
#' https://docs.rstudio.com/connect/1.5.4/admin/package-management.html
runCasanovaApp <- function() {
  appDir <- system.file("shiny-examples", "CasanovaApp", package = "Casanova")
  if (appDir == "") {
    stop("Could not find example directory. Try re-installing `Casanova`.", call. = FALSE)
  }

  shiny::runApp(appDir, display.mode = "normal")
}
