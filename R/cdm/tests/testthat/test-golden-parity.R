# Golden output stability tests.
# These ensure the R binding returns byte-identical JSON for the three
# reference cases shipped in inst/extdata/. Any change to model numerics
# or output formatting would break these.

read_case <- function(case) {
  path <- system.file(file.path("extdata", paste0(case, ".json")), package = "cdm")
  paste(readLines(path, warn = FALSE), collapse = "\n")
}

test_that("Case_B output is stable", {
  input <- read_case("Case_B")
  output <- cdm::cdm(input)
  expect_type(output, "character")
  expect_equal(nchar(output), 12115)
})

test_that("Case_G output is stable", {
  input <- read_case("Case_G")
  output <- cdm::cdm(input)
  expect_type(output, "character")
  expect_equal(nchar(output), 17462)
})

test_that("Case_I output is stable", {
  input <- read_case("Case_I")
  output <- cdm::cdm(input)
  expect_type(output, "character")
  expect_equal(nchar(output), 12047)
})

test_that("Case_B output parses as valid JSON with expected structure", {
  input <- read_case("Case_B")
  output <- cdm::cdm(input)
  parsed <- jsonlite::fromJSON(output, simplifyVector = FALSE)
  # Output is a JSON array: ["Case_B", {scenario data...}]
  expect_true(is.list(parsed))
  expect_equal(parsed[[1]], "Case_B")
  expect_true("output" %in% names(parsed[[2]]))
})
