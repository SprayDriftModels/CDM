cdm <- function(config) {
  .Call('_cdm', PACKAGE='cdm', config)
}

cdm.version <- function() {
  .Call('_version', PACKAGE='cdm')
}
