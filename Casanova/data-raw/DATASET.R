
DDD_Params <- read.csv("data-raw/DDD_Params.csv")
Nozzle_Params <- read.csv("data-raw/Nozzle_Params.csv")
ExampleDSD <- read.csv("data-raw/Example.DSD.csv")
## code to prepare `DATASET` dataset goes here

usethis::use_data("DATASET")
