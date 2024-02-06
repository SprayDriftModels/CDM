#### -*- R -*-
require(cdm)
config.file <- system.file("extdata", "Case_B.json", package="cdm")
config <- readChar(config.file, file.info(config.file)$size)
output <- cdm(config)
print(jsonlite::fromJSON(output))
