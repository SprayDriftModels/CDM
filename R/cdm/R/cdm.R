cdm <- function(config) {
  result <- .Call('_cdm', PACKAGE = 'cdm', config)

  if (!is.list(result) || is.null(result$status_code)) {
    # Backwards compatibility with an older binding that returned the JSON
    # string directly (or NULL on failure).
    return(result)
  }

  if (result$status_code != 0L) {
    message <- result$message
    if (is.null(message) || !nzchar(message)) {
      message <- "CDM model failed with no diagnostic message."
    }
    cond <- structure(
      class = c("cdm_model_error", "error", "condition"),
      list(
        message = message,
        call = sys.call(-1),
        status_code = result$status_code
      )
    )
    stop(cond)
  }

  result$output
}

cdm.version <- function() {
  .Call('_version', PACKAGE='cdm')
}
