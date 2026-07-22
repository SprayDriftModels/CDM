# Tests for the R binding's structured return and error handling contract.

test_that("cdm() returns a character string on valid input", {
  input <- paste(readLines(
    system.file("extdata/Case_B.json", package = "cdm"), warn = FALSE
  ), collapse = "\n")
  result <- cdm::cdm(input)
  expect_type(result, "character")
  expect_true(nchar(result) > 0)
})

test_that("cdm() raises a classed cdm_model_error on malformed JSON", {
  bad_json <- '{"bad": {}'

  err <- tryCatch(cdm::cdm(bad_json), cdm_model_error = function(e) e)

  expect_s3_class(err, "cdm_model_error")
  expect_true(nzchar(conditionMessage(err)))
  expect_true(is.integer(err$status_code))
  expect_true(err$status_code != 0L)
})

test_that("cdm_model_error is catchable as a plain error", {
  bad_json <- '{"bad": {}'
  expect_error(cdm::cdm(bad_json))
})

test_that("cdm_model_error message contains a useful diagnostic", {
  bad_json <- '{"bad": {}'

  err <- tryCatch(cdm::cdm(bad_json), cdm_model_error = function(e) e)

  # CDM's JSON parser should mention the parse problem
  expect_match(conditionMessage(err), "parse|error|unexpected", ignore.case = TRUE)
})

test_that("cdm.version() returns a non-empty version string", {
  v <- cdm::cdm.version()
  expect_type(v, "character")
  expect_true(nzchar(v))
  expect_match(v, "^[0-9]+\\.[0-9]+\\.[0-9]+$")
})
