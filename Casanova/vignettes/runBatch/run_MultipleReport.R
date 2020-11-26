dir <- "~/mondep/Casanova/vignettes/runBatch/Data/"
files <- list.files(dir)
files <- grep(".csv",files,value=T)
setwd("~/mondep/Casanova/vignettes/runBatch/")
for(j in 1:length(files)){
  rmarkdown::render("Parameterized_Naresh.Rmd", params = list(
    datasheet = paste0(dir,files[j]),inputs="DefaultInputs.R"),output_file = paste0(gsub(".csv","",files[j]),".html"))
}

for(j in 1:3){
  rmarkdown::render("Parameterized_Naresh.Rmd", params = list(
    datasheet = paste0(dir,files[j]),inputs="DefaultInputs.R"),output_file = gsub("[^-\\./a-zA-Z0-9[:space:]]", "",paste0(gsub(".csv","",files[j]),".html"))
)}
