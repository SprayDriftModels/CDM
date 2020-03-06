## Initiate environment conditions -- hard-coded; not influenced by the user
########################################################################################

## Check for packages, if not present install
list.of.packages <- c("shiny",
                      "shinydashboard",
                      "nlstools",
                      "tidyverse",
                      "ggplot2",
                      "nleqslv",
                      "DT",
                      "shinyjs",
                      "V8",
                      "gridExtra",
                      "deSolve")
new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages, dependencies = TRUE, repos = structure(c(CRAN="http://cloud.r-project.org/")))

## Load libraries
library(shiny)
library(shinydashboard)
library(nlstools)
library(tidyverse)
library(ggplot2)
library(nleqslv)
library(DT)
library(shinyjs)
library(V8)
library(gridExtra)
library(deSolve)
library(doParallel) 
library(foreach) 

## Create "notin" function
`%notin%` <- Negate(`%in%`)

## Create options for canopy/wind speed 
MeasurementOptions = c('One', 'Two')

## Load hard-coded inputs
Nozzle_params <- as_tibble(read.csv("./Constants/Nozzle_params.csv", header = T))
DDD_params <- as_tibble(read.csv("./Constants/DDD_params.csv", header = T))

## Load example DSD file
Example.DSD <- read.csv("Templates/DSD_template.csv", header = T)

## Load all functions used
source("./Rscripts/1_psd_function.R")
source("./Rscripts/2_wet_bulb_function.R")
source("./Rscripts/3_wvprofile_params.R")
source("./Rscripts/3_WV2measurements.R")
source("./Rscripts/4_Nozzle_Characteristics.R")
source("./Rscripts/4_Droplet_Transport_function.R")
source("./Rscripts/5_Deposition_Calcs_function.R")

## Set "Driver" -- whether running in shiny or terminal (main)
Driver = "shiny"

## Set up user interface (ui)
########################################################################################
ui <- shinyUI(
  
  fluidPage(
    ## Add Exponent logo
    #titlePanel(img(src = "Logo.jfif", height = 120, width = 200)),
    
    ## Create panel for inputs
    sidebarLayout(
      sidebarPanel(
        tags$head(
          tags$style(
            type = "text/css",
            ".nav-tabs {font-size: 10px} ",
            "input:invalid {background-color: #FFCCCC;}")), #turn red if entry is invalid
        
        style = "background-color: #78d9c9;", # choose background color
        tags$style(
          type = "text/css", # add css-style to the lists of selected categories and the dropdown menu
          ".selectize-input { font-size: 12pt; line-height: 13pt;} 
                            .selectize-dropdown { font-size: 12pt; line-height: 13pt; }"),
        width = 3, # set panel width
        
        
        ########################################################
        ##### Part 1 DSD Curve Fitting
        
        ## Title
        h3("Step 1: DSD Curve Fitting"),
        
        ## Input: Select a file ----
        fileInput("file1", "Choose CSV file",
                  multiple = TRUE,
                  accept = c(
                    "text/csv",
                    "text/comma-separated-values,text/plain",
                    ".csv")),
        
        ## Download: Example file ----
        downloadButton(
          outputId = "download.example.DSD.csv",
          label = "Download example datasheet for DSD input"),
        
        h3(""), #used to create space
        uiOutput("action_fit_dsd"),  # button to plot output
        

        ########################################################
        ##### Part 2 Wet Bulb Calculation
        
        ## Horizontal line ----
        tags$hr(),
        
        # Example datasets/templates to download
        ## Title
        h3("Step 2: Wet Bulb Calculation"),
        
        numericInput(inputId = "Tair",
                     label = "Dry air temperature (Celcius):", # ***Do we want to let them enter in F too? (then convert)
                     value = "NA",
                     #value = "17.689", #*** Debugging purposes
                     step = 0.001, #*** How many decimal places do we want?
                     min = -50, #****Is there a good min temp?
                     max = 50),  #****Is there a good max temp?
        
        ## Input Barometric pressure, mmHg abs
        numericInput(inputId = "Patm",
                     label = "Barometric pressure (mmHg abs):", 
                     #value = "NA",
                     value = "760", #*** Debugging purposes
                     step = 0.001, #*** How many decimal places do we want?
                     min = 300, #***Is there a good min? https://www.avs.org/AVS/files/c7/c7edaedb-95b2-438f-adfb-36de54f87b9e.pdf
                     max = 800),
        
        ## Input Percent Relative Humidity
        numericInput(inputId = "RH",
                     label = "Relative humidity (percent):",
                     #value = "NA",
                     value = "35.65", #*** Debugging purposes
                     step = 0.001, #*** How many decimal places do we want?
                     min = 0,
                     max = 100),
        
        uiOutput("action_Twb"),  # button to plot output
        
        ########################################################
        ##### Part 3 Wind Profile
        
        ## Horizontal line ----
        tags$hr(),
        
        # Example datasets/templates to download
        ## Title
        h3("Step 3: Wind Profile Calculation"),
        
        selectizeInput(
          inputId = "NumberMeasures_chosen",
          label = 'Canopy/wind measurements',
          choice = c('Choose number of measurements' = '', unique(MeasurementOptions)),
          multiple = FALSE,
          selected = NULL
        ),
        
        ## Drop-downs for data input depend on Measurements.chosen
        uiOutput("Elevation_wind_speed_1"), #Options 1 and 2
        uiOutput("MPH_wind_speed_1"),   #Options  2 only
        uiOutput("Elevation_wind_speed_2"), #Options 1 and 2
        uiOutput("MPH_wind_speed_2"),   #Options  2 only
        
        uiOutput("Canopy_height"),  #Options 1 only
        uiOutput("Boom_height"),    #Options 1 only
        uiOutput("Lambda"),  #Options 1 only
        uiOutput("action_wet"),  #plot output
        
        
        ########################################################
        ##### Part 4 Droplet Transport Calculations
        
        ## Horizontal line ----
        tags$hr(),
        
        # Example datasets/templates to download
        ## Title
        h3("Step 4: Droplet Transport Calculations"),
        
        #Tair and RH loaded already in Part 3
        
        numericInput(inputId = "rhow",
                     label = "Density of pure water in droplet (g/cm3):",
                     value = "NA",
                     #value = "1", # Default value
                     step = 0.001, #*** How many decimal places do we want?
                     min = 0, #****Is there a good min?
                     max = 1),  #****Is there a good max?
        
        numericInput(inputId = "rhos",
                     label = "Density of dissolved solids in droplet (g/cm3):",
                     #value = "NA",
                     value = "2.015", # Default value
                     step = 0.001, #*** How many decimal places do we want?
                     min = 0, #****Is there a good min?
                     max = 100),  #****Is there a good max?
        
        numericInput(inputId = "xs0",
                     label = "Mass fraction total dissolved solids in solution:",
                     #value = "NA",
                     value = "0.01", # Default value
                     step = 0.000001, #*** How many decimal places do we want?
                     min = 0, #****Is there a good min?
                     max = 1),  #****Is there a good max?
        
        numericInput(inputId = "H0",
                     label = "Height of nozzle above ground (in):",
                     #value = "NA",
                     value = "24", # Default value
                     step = 0.001, #*** How many decimal places do we want?
                     min = 0, #****Is there a good min?
                     max = 1000),  #****Is there a good max?
        
        numericInput(inputId = "hcm",
                     label = "Canopy height (cm):",
                     #value = "NA",
                     value = "0", # Default value
                     step = 0.001, #*** How many decimal places do we want?
                     min = 0, #****Is there a good min?
                     max = 1000),  #****Is there a good max?
        
        numericInput(inputId = "app_p",
                     label = "Nozzle pressure (psi):",
                     #value = "NA",
                     value = "63", # Default value
                     step = 0.001, #*** How many decimal places do we want?
                     min = 0, #****Is there a good min?
                     max = 1000),  #****Is there a good max?
        
        numericInput(inputId = "angle",
                     label = "Nozzle angle (degrees):",
                     #value = "NA",
                     value = "110", # Default value
                     step = 0.001, #*** How many decimal places do we want?
                     min = 0, #****Is there a good min?
                     max = 360),  #****Is there a good max?
        
        numericInput(inputId = "rhosoln",
                     label = "Mix density (kg/m3):",
                     #value = "NA",
                     value = "1008.7", # Default value
                     step = 0.001, #*** How many decimal places do we want?
                     min = 0, #****Is there a good min?
                     max = 10000),  #****Is there a good max?
        
        uiOutput("action_drop_trans"),  #plot output
        
        h3(""), #used to create space
        
        ## Button to download data used for plotting
        downloadButton(
          outputId = "download.part4.data",
          label = "Download Part 4 Results"
        ),
        
        ########################################################
        ##### Part 5 Calculate Deposition with Distance
        
        ## Horizontal line ----
        tags$hr(),
        
        # Example datasets/templates to download
        ## Title
        h3("Step 5: Calculate Deposition with Distance"),
        
        numericInput(inputId = "IAR",
                     label = "Intended Application Rate of Dicamba (lb/acre):",
                     value = "NA",
                     #value = "0.4996", # Default value
                     step = 0.0000001, #*** How many decimal places do we want?
                     min = 0, #****Is there a good min?
                     max = 100),  #****Is there a good max?
        
        numericInput(inputId = "xactive",
                     label = "Dicamba conc in tank solution (wtfraction):",
                     #value = "NA",
                     value = "0.003884", # Default value
                     step = 0.0000001, #*** How many decimal places do we want?
                     min = 0, #****Is there a good min?
                     max = 1),  #****Is there a good max?
        
        numericInput(inputId = "FD",
                     label = "Downwind field depth (ft):",
                     #value = "NA",
                     value = "240.16", # Default value
                     step = 0.001, #*** How many decimal places do we want?
                     min = 0, #****Is there a good min?
                     max = 10000),  #****Is there a good max?
        
        numericInput(inputId = "PL",
                     label = "Crosswind field width (ft):",
                     #value = "NA",
                     value = "787.4", # Default value
                     step = 0.001, #*** How many decimal places do we want?
                     min = 0, #****Is there a good min?
                     max = 10000),  #****Is there a good max?
        
        numericInput(inputId = "NozzleSpacing",
                     label = "Space between nozzles on Boom (in):",
                     #value = "NA",
                     value = "20", # Default value
                     step = 0.001, #*** How many decimal places do we want?
                     min = 0, #****Is there a good min?
                     max = 100),  #****Is there a good max?
        
        numericInput(inputId = "psipsipsi",
                     label = "Horizontal variation in wind direction around mean direction, 1 stdev (degrees):",
                     #value = "NA",
                     value = "10.7", # Default value
                     step = 0.001, #*** How many decimal places do we want?
                     min = 0, #****Is there a good min?
                     max = 100),  #****Is there a good max?
        
        numericInput(inputId = "Dpmax",
                     label = "Dpmax (µm):",
                     #value = "NA",
                     value = "1350", # Default value
                     step = 0.001, #*** How many decimal places do we want?
                     min = 0, #****Is there a good min?
                     max = 10000),  #****Is there a good max?
        
        numericInput(inputId = "DDpmin",
                     label = "DDpmin (µm):",
                     #value = "NA",
                     value = "18", # Default value
                     step = 0.001, #*** How many decimal places do we want?
                     min = 0, #****Is there a good min?
                     max = 1000),  #****Is there a good max?
        
        
        numericInput(inputId = "MMM",
                     label = "Number of droplet size bins (MMM):",
                     #value = "NA",
                     value = "500", # Default value
                     step = 0.001, #*** How many decimal places do we want?
                     min = 0, #****Is there a good min?
                     max = 10000),  #****Is there a good max?
        
        numericInput(inputId = "lambda_res",
                     label = "Resolution of deposition calculations (higher numbers increase accuracy):",
                     #value = "NA",
                     value = "3", # Default value
                     step = 0.001, #*** How many decimal places do we want?
                     min = 0, #****Is there a good min?
                     max = 100),  #****Is there a good max?
        
        uiOutput("action_plot_dep"),  #plot output
        
        h3(""), #used to create space
        
        ## Button to download data used for plotting
        downloadButton(
          outputId = "download.part5.data",
          label = "Download Part 5 Results"
        ),
      ),
      
      ## Plot output
      mainPanel(
        
        ## Part 1 Results
        fluidRow(
          h2("Results")
        ),
          fluidRow(
          h3("Step 1: DSD Curve Fitting"),
          
          ## Plot results when ready (i.e., when output.return_part1_results is created)
          conditionalPanel("output.return_part1_results",
                           column(9,
                                  align="center",
                                  plotOutput('Fit_plot')),
                           column(3,
                                  align = "center",
                                  tableOutput('Part1_table')),
                           tags$style(type='text/css', "#Part1_table { width:100%; margin-top: 100px;}")),
          tags$hr()
        ),
        
        ## Part 2 Results
        fluidRow(
          h3("Step 2: Wet Bulb Calculation Results"),
          
          ## Plot results when ready (i.e., when output.return_part2_results is created)
          conditionalPanel("output.return_part2_results",
                           column(12,
                                  verbatimTextOutput("Twb_values"),
                                  tags$head(tags$style(HTML("
                              #Twb_values {
                                font-size: 16px;
                              }
                              "))))),
          tags$hr()
        ),
          
          ## Part 3 Results
          fluidRow(
            h3("Step 3: Wind Profile Calculation Results"),
            
            ## Plot results when ready (i.e., when output.return_part3_results is created)
            conditionalPanel("output.return_part3_results",
                             column(12,
                                    verbatimTextOutput("z0_uf"),
                                    tags$head(tags$style(HTML("
                              #z0_uf {
                                font-size: 16px;
                              }
                              "))),
                                    # conditionalPanel("input.NumberMeasures_chosen == 'One'",
                                    #                  plotOutput('wv_plot'))
                                    )
                             ),
            tags$hr()
          ),
          
          ## Part 4 Results
          fluidRow(
            h3("Step 4: Droplet Transport Calculation Results"),
            
            ## Plot results when ready (i.e., when output.return_part4_results is created)
            conditionalPanel("output.return_part4_results",
                             column(4,
                                    tabsetPanel(
                                      id = 'Part4_Table',
                                      tabPanel("Centerline", DT::dataTableOutput("Droplet1.table")),
                                      tabPanel("Downwind", DT::dataTableOutput("Droplet2.table")),
                                      tabPanel("Upwind", DT::dataTableOutput("Droplet3.table")))),
                             column(8,
                                    plotOutput('Part4_plot')),
                             tags$style(type='text/css', "#Part4_plot { width:100%; margin-top: 100px;}"),
            ),
            tags$hr()
          ),
          
          ## Part 5 Results
          fluidRow(
            h3("Step 5: Deposition with Distance Calculations Results"),
            
            ## Plot results when ready (i.e., when output.return_part5_results is created)
            conditionalPanel("output.return_part5_results",
                             column(12,
                                    plotOutput('dep_plot'))
            )
          )
        )
      ),
    )
  )






#########################################################################################################
# Set up server logic 
server <- shinyServer(function(input, output, session) {
  
  ## Upload DSD data
  selected.data <- reactive({
    inFile <- input$file1
    
    if (is.null(inFile)) {
      return(NULL)
    }
    file.chosen <- read.csv(inFile$datapath,
                            header = T
    )
    return(file.chosen)
  })
  
  
  ############################################################################################################
  ## PART 1 DSD Curve Fitting
  
  ## Process input data files
  Data2 <- reactive({
    req(selected.data())
    
    ## Calculate mean for however many trials were included
    ymean <- selected.data() %>%
      select(-Droplet_Size_microns) %>%
      apply(.,1,mean)
    
    ## Determine where to draw the cut-off (begin with first value over zero and end with first value that reaches 100)
    firsty <- min(which(ymean > 0))
    lasty <- max(which(ymean < 100))+1
    
    ## Apply cut-off to y and Dpdata datasets
    y <- ymean %>%
      tibble::enframe() %>%
      slice(firsty:lasty) %>%
      pull(value)
    
    Dpdata <- selected.data() %>%
      select(Droplet_Size_microns) %>%
      slice(firsty:lasty) %>%
      pull(Droplet_Size_microns)
    
    Data2 <- list(y = y, Dpdata = Dpdata)
    
    return(Data2)
  })

  
  ## Obtain fitted parameters of the drop size distribution model
  pars <- reactive({
    req(Data2())
    
    ## Calculate parameters using the loaded function "1a_psd_function.R"
    pars <- psd(Data2()$y,Data2()$Dpdata)
    
    return(pars)
  })
  
  ## Create action button - user must push button to generate output
  output$action_fit_dsd <- renderUI({
    return(actionButton("action_fit_dsd", "Fit DSD")) 
  })
  
  
  ## Output Part 1 (using action button to avoid warnings/errors while waiting for user input)
  
  ## Plot
  action_Part1 <- eventReactive(input$action_fit_dsd, {
    req(pars())

    part1_plot <- pars()$plot
    
    return(part1_plot)
  })
  
  ## Plot
  output$Fit_plot <- renderPlot({
    req(action_Part1())
    pars()$plot
  })
  
  # Table
  output$Part1_table <- renderTable({
    req(action_Part1())
    pars()$table
  })
  
  ## Print all results only when ready
  output$return_part1_results <- renderText({
    req(action_Part1())
    return(1) 
  })
  outputOptions(output, "return_part1_results", suspendWhenHidden = FALSE)  
  
  
  
  ############################################################################################################
  ## PART 2 Wet Bulb Calculation
  
  # The following contains the wet bulb temperature
  # Inputs are in sequence Dry air temperature (Tair) degrees C, Barometric pressure (Patm) in mmHg abs, and Percent relative humidity (RH)
  # Outputs are: DTwb,Twb
  
  Twb <- reactive({
    req(input$Tair)
    req(input$Patm)
    req(input$RH)
    Twb <- wet_bulb(input$Tair, input$Patm, input$RH)  
    
    return(Twb)
  })
  
  ## Create action button - user must push button to generate output
  output$action_Twb <- renderUI({
    return(actionButton("action_Twb", "Calculate Wet Bulb Temp")) 
  })
  
  ## Create text output when action button pressed
  action_Part2 <- eventReactive(input$action_Twb, {
    req(Twb())
    
    return(paste0("Change in Wet Bulb Temperature (DTwb): ", round(Twb()[1],2), "\nWet Bulb Temperature (Twb): ", round(Twb()[2],2)))
  })
  
  ## Plot text
  output$Twb_values <- renderText({
    req(action_Part2())
    action_Part2()
  })
  
  ## Print all results only when ready
  output$return_part2_results <- renderText({
    req(action_Part2())
    return(1) 
  })
  outputOptions(output, "return_part2_results", suspendWhenHidden = FALSE)  
  
  
  ############################################################################################################
  ## PART 3 Wind Profile
  
  ##### Canopy Height
  output$Elevation_wind_speed_1 <- renderUI({
    if (is.null(input$NumberMeasures_chosen))
      return()
    
    if (input$NumberMeasures_chosen == "One" | input$NumberMeasures_chosen == "Two")
      return(
        numericInput(inputId = "Elevation_wind_speed_1",
                     label = "1st Elevation wind speed (ft):", # ***Do we want to let them enter in meters too? (then convert)
                     value = "NA",
                     step = 0.001, #*** How many decimal places do we want?
                     min = 0, #*** Is this correct
                     max = 5000 )) #*** Is there a good max elevation?
  })
  
  output$Elevation_wind_speed_2 <- renderUI({
    if (is.null(input$NumberMeasures_chosen))
      return()
    
    if (input$NumberMeasures_chosen == "One")
      return()
    
    if (input$NumberMeasures_chosen == "Two")
      return(
        numericInput(inputId = "Elevation_wind_speed_2",
                     label = "2nd Elevation wind speed (ft):", # ***Do we want to let them enter in meters too? (then convert)
                     value = "1.66667", #*** Debugging purposes
                     step = 0.00001, #*** How many decimal places do we want?
                     min = 0, #*** Is this correct
                     max = 5000 )) #*** Is there a good max elevation?
  })
  
  ##### Wind Speed
  output$MPH_wind_speed_1 <- renderUI({
    if (is.null(input$NumberMeasures_chosen))
      return()
    
    if (input$NumberMeasures_chosen == "One" | input$NumberMeasures_chosen == "Two")
      return(
        numericInput(inputId = "MPH_wind_speed_1",
                     label = "1st wind speed (mph):",
                     value = "12.8",
                     step = 0.001, #*** How many decimal places do we want?
                     min = 0,
                     max = 250))
  })
  
  output$MPH_wind_speed_2 <- renderUI({
    if (is.null(input$NumberMeasures_chosen))
      return()
    
    if (input$NumberMeasures_chosen == "One")
      return()
    
    if (input$NumberMeasures_chosen == "Two")
      return(
        numericInput(inputId = "MPH_wind_speed_2",
                     label = "2nd wind speed (mph):",
                     value = "9.44",
                     step = 0.001, #*** How many decimal places do we want?
                     min = 0,
                     max = 250))
  })
  
  ##### Canopy, Lambda, and Boom (only used when one set of wind speed and elevation selected)
  output$Canopy_height <- renderUI({
    if (is.null(input$NumberMeasures_chosen))
      return()
    
    if (input$NumberMeasures_chosen == "Two")
      return()
    
    if (input$NumberMeasures_chosen == "One")
      return(
        numericInput(inputId = "Canopy_height",
                     label = "Canopy_height (in):",
                     value = "4",
                     step = 0.001, #*** How many decimal places do we want?
                     min = 0, #*** Is this 0?
                     max = 5000)) #*** Is there a good max height?
  })
  
  ##### Calculations
  wvprofile_params <- reactive({
    req(Twb)
    req(input$NumberMeasures_chosen)
    
    if (is.null(input$NumberMeasures_chosen))
      return()
    
    if (input$NumberMeasures_chosen == "One")
      return(wvprofile(input$Elevation_wind_speed_1,
                       input$MPH_wind_speed_1,
                       input$Canopy_height))
    
    if (input$NumberMeasures_chosen == "Two")
      return(WV2m(input$Elevation_wind_speed_1,
                  input$Elevation_wind_speed_2,
                  input$MPH_wind_speed_1,
                  input$MPH_wind_speed_2))
    
  })       
  
  ## Create action button
  output$action_wet <- renderUI({
    if (is.null(input$NumberMeasures_chosen))
      return()
    
    if (input$NumberMeasures_chosen == "Two")
      return(actionButton("action_wet", "Calculate wind profile")) 
    
    if (input$NumberMeasures_chosen == "One")
      return(actionButton("action_wet", "Calculate wind profile")) 
  })
  
  ## Create text output when action button pressed
  action_Part3 <- eventReactive(input$action_wet, {
    req(wvprofile_params())
    
    if (is.null(input$NumberMeasures_chosen)) {
      return()
    }
    
      part3.text <- paste0("Friction height, cm (z0): ", round(wvprofile_params()[1],2), "\nFriction velocity, cm/sec (uf): ", round(wvprofile_params()[2],2))
      part3.list <- list("text" = part3.text)

      return(part3.list)
    # }
  })
  
  ## Plot text
  output$z0_uf <- renderText({
    req(action_Part3())
    action_Part3()$text
  })
  
  # ## Plot figure
  # output$wv_plot <- renderPlot({
  #   req(action_Part3())
  #   action_Part3()$plot
  # })
  
  ## Print all results only when ready
  output$return_part3_results <- renderText({
    req(action_Part3())
    return(1) 
  })
  outputOptions(output, "return_part3_results", suspendWhenHidden = FALSE)  
  
  
  ############################################################################################################
  ## PART 4 Droplet Transport
  
  ## Action button to plot output
  output$action_drop_trans <- renderUI({
    return(actionButton("action_drop_trans", "Calculate Droplet Transport")) 
  })
  
  ## Calculations
  Droplet_Transport_Results <- eventReactive(input$action_drop_trans, {
    
    req(input$Tair)
    req(input$RH)
    req(input$rhow)
    req(input$rhos)
    req(input$xs0)
    req(input$H0)
    req(input$hcm)
    req(input$app_p)
    req(input$angle)
    req(input$rhosoln)
    req(wvprofile_params)
    req(input$NumberMeasures_chosen)
    
    ## Hard-coded parameters specific to nozzle used (file can be changed in Constants directory)
    p <- Nozzle_params %>% select(p)
    NF <- Nozzle_params %>% select(NF)
    ddd1 <- DDD_params$ddd1
    ddd2 <- DDD_params$ddd2
    ddd3 <- DDD_params$ddd3
    
    # if(input$NumberMeasures_chosen == "One"){
    #   z0 <- wvprofile_params()[1]
    #   Uf <- wvprofile_params()[2]
    # }
    
    # if(input$NumberMeasures_chosen == "Two"){
      z0 <- wvprofile_params()[1]
      Uf <- wvprofile_params()[2]
    # }
    
    ## Calculated from previous function
    DTwb <- Twb()[1] # Wetbulb temperature depression, C
    
    ## Nozzle characteristics calculation
    charac <- charact_cal(input$app_p, input$angle, input$rhosoln)
    
    ## Create progress bar
    withProgress(message = "Solving Straight Down Problem", value = 0, {
    
      droplet_1 <- droplet_transport(input$Tair,
                                     input$RH,
                                     input$rhow,
                                     input$rhos,
                                     input$xs0,
                                     input$H0,
                                     DTwb,
                                     input$hcm,
                                     Uf,
                                     z0,
                                     input$app_p,
                                     charac[1],
                                     charac[2],
                                     ddd1,
                                     Driver)
    }) # End of progress bar
    
    ## Create progress bar
    withProgress(message = "Solving with Wind Problem", value = 0, {
      
      droplet_2 <- droplet_transport(input$Tair,
                                     input$RH,
                                     input$rhow,
                                     input$rhos,
                                     input$xs0,
                                     input$H0,
                                     DTwb,
                                     input$hcm,
                                     Uf,
                                     z0,
                                     input$app_p,
                                     charac[3],
                                     charac[4],
                                     ddd2,
                                     Driver)
    }) # End of progress bar

    ## Create progress bar
    withProgress(message = "Solving against Wind Problem", value = 0, {
      
      droplet_3 <- droplet_transport(input$Tair,
                                     input$RH,
                                     input$rhow,
                                     input$rhos,
                                     input$xs0,
                                     input$H0,
                                     DTwb,
                                     input$hcm,
                                     Uf,
                                     z0,
                                     input$app_p,
                                     charac[5],
                                     charac[6],
                                     ddd3,
                                     Driver)
    }) # End of progress bar
    
    
    Droplet_Transport_Results.list <- list("droplet_1" = droplet_1,
                                           "droplet_2" = droplet_2,
                                           "droplet_3" = droplet_3)
    
  })
  
  ## Output from Part 4
  
  ## Table
  output$Droplet1.table <- DT::renderDataTable({
    req(Droplet_Transport_Results())
    
    ## Identify all non-zero results 
    nonzero <- Droplet_Transport_Results()$droplet_1 %>%
      filter('Xdist' != 0) %>%
      select('Xdist') %>%
      unique()
    
    ## Create datatable and highlight zeroes in red
    DT::datatable(Droplet_Transport_Results()$droplet_1,
                  options = list(dom = 'lt'),
                  rownames = FALSE,
                  colnames=c("Initial Droplet Diameter (microns)",
                             "Distance Traveled to Depositions from Nozzle Centerline (ft)"),
                  caption =  htmltools::tags$caption("Rows highlighted in red, likely non-convergence",
                                                     style="color:red")) %>%
      formatStyle('Xdist', 
                  backgroundColor = styleEqual(c(0, nonzero), c('red', 'white'))) %>%
      formatRound(columns=c('Xdist', 'Dp.1.23.'),
                  digits=3)
    
  })
  
  
  
  output$Droplet2.table <- DT::renderDataTable({
    req(Droplet_Transport_Results())
    
    ## Identify all non-zero results 
    nonzero <- Droplet_Transport_Results()$droplet_2 %>%
      filter('Xdist' != 0) %>%
      select('Xdist') %>%
      unique()
    
    ## Create datatable and highlight zeroes in red
    DT::datatable(Droplet_Transport_Results()$droplet_2,
                  options = list(dom = 'lt'),
                  rownames = FALSE,
                  colnames=c("Initial Droplet Diameter (microns)",
                             "Distance Traveled to Depositions from Nozzle Centerline (ft)"),
                  caption =  htmltools::tags$caption("Rows highlighted in red, likely non-convergence",
                                                     style="color:red")) %>%
      formatStyle('Xdist', 
                  backgroundColor = styleEqual(c(0, nonzero), c('red', 'white'))) %>%
      formatRound(columns=c('Xdist', 'Dp.1.23.'),
                  digits=3)
  })
  
  output$Droplet3.table <- DT::renderDataTable({
    req(Droplet_Transport_Results())
    
    ## Identify all non-zero results 
    nonzero <- Droplet_Transport_Results()$droplet_3 %>%
      filter('Xdist' != 0) %>%
      select('Xdist') %>%
      unique()
    
    ## Create datatable and highlight zeroes in red
    DT::datatable(Droplet_Transport_Results()$droplet_3,
                  options = list(dom = 'lt'),
                  rownames = FALSE,
                  colnames=c("Initial Droplet Diameter (microns)",
                             "Distance Traveled to Depositions from Nozzle Centerline (ft)"),
                  caption =  htmltools::tags$caption("Rows highlighted in red, likely non-convergence",
                                                     style="color:red")) %>%
      formatStyle('Xdist', 
                  backgroundColor = styleEqual(c(0, nonzero), c('red', 'white'))) %>%
      formatRound(columns=c('Xdist', 'Dp.1.23.'),
                  digits=3)
  })
  
  ## Create Figure
  output$Part4_plot <- renderPlot({
    req(Droplet_Transport_Results())
    
    droplet1_data <- as_tibble(Droplet_Transport_Results()$droplet_1) %>%
      mutate(Droplet = "Centerline",
             ColorSet = "#ffd700")
    droplet2_data <- as_tibble(Droplet_Transport_Results()$droplet_2) %>%
      mutate(Droplet = "Downwind",
             ColorSet = "#00ffd7")
    droplet3_data <- as_tibble(Droplet_Transport_Results()$droplet_3) %>%
      mutate(Droplet = "Upwind",
             ColorSet = "#d700ff")
    
    All_droplet_data <- rbind(droplet1_data,
                              droplet2_data,
                              droplet3_data)
      
    Part4_plot <- ggplot(All_droplet_data, aes(x = Xdist, y = Dp.1.23., color = Droplet)) +
      geom_point(size = 3, alpha = 0.5) +
      scale_color_manual(values = c("#ffd700", "#00ffd7", "#d700ff")) +
      ylab("Initial Droplet Diameter (microns)") +
      xlab("Distance Traveled to Depositions from Nozzle Centerline (ft)") +
      theme_bw() +
      theme(
        legend.title = element_blank(),
        legend.background = element_rect(fill=alpha('white', 0.4)),
        legend.position = "right",
        legend.text = element_text(size = 16),
        axis.line = element_line(colour = "black"),
        axis.text.y = element_text(size = 16),
        axis.text.x = element_text(size = 16),
        axis.title.y = element_text(size = 16, vjust= 1.5),
        axis.title.x = element_text(size = 16)
      )
    return(Part4_plot)
  })
  
  ## Print all results only when ready
  output$return_part4_results <- renderText({
    req(Droplet_Transport_Results())
    return(1) 
  })
  outputOptions(output, "return_part4_results", suspendWhenHidden = FALSE)  
  
  ## Create data for download
  Part4_results <- reactive({
    req(Droplet_Transport_Results())
    
    droplet1_data <-
      as_tibble(Droplet_Transport_Results()$droplet_1) %>%
      mutate(Droplet = "Centerline")
    droplet2_data <-
      as_tibble(Droplet_Transport_Results()$droplet_2) %>%
      mutate(Droplet = "Downwind")
    droplet3_data <-
      as_tibble(Droplet_Transport_Results()$droplet_3) %>%
      mutate(Droplet = "Upwind")
    
    All_droplet_data <-
      rbind(droplet1_data,
            droplet2_data,
            droplet3_data)
    
    All_droplet_data <-
      All_droplet_data %>%
      select("Droplet_diameter" = "Dp.1.23.",
             "Distance_traveled" = "Xdist",
             Droplet)
    
    return(All_droplet_data)
  })
  
  ## Downloadable csv of data used for plotting 
  output$download.part4.data <- downloadHandler(
    
    filename = function() {
      paste0(
        "Droplet_calculation_results.csv"
      )
    },
    content = function(file) {
      write.csv(Part4_results(), file, row.names = FALSE)
    }
  )
  
  ############################################################################################################
  ## PART 5 Deposition Calculations
  
  Deposition <- reactive({
    req(pars())
    req(Droplet_Transport_Results())
    req(input$rhosoln)
    req(input$IAR)
    req(input$xactive)
    req(input$FD)
    req(input$PL)
    req(input$NozzleSpacing)
    req(input$psipsipsi)
    req(input$Dpmax)
    req(input$DDpmin)
    req(input$MMM)
    req(input$lambda_res)
    
    
    # Calculated in previous steps
    a <- unname(pars()$res)  
    Cent <- Droplet_Transport_Results()$droplet_1[2]$Xdist
    Dwnd <- Droplet_Transport_Results()$droplet_2[2]$Xdist
    Uwnd <- Droplet_Transport_Results()$droplet_3[2]$Xdist
    rhoL <- input$rhosoln/1000
    
    withProgress(message = 'Deposition calculation', detail = "percent complete", value = 0, {
      
    Deposition <- deposition_calcs(input$IAR,
                                   input$xactive,
                                   input$FD,
                                   input$PL,
                                   input$NozzleSpacing,
                                   input$psipsipsi,
                                   rhoL,
                                   Cent,
                                   Dwnd,
                                   Uwnd,
                                   input$Dpmax,
                                   input$DDpmin,
                                   a,
                                   input$MMM,
                                   input$lambda_res,
                                   Driver)
    })
    
    return(Deposition)
  })
  
  ## Action button to plot output
  output$action_plot_dep <- renderUI({
    return(actionButton("action_plot_dep", "Calculate Deposition")) 
  })
  
  
  # Output Part 5 using action button to avoid warnings/errors while waiting for user input
  action_dep_plot <- eventReactive(input$action_plot_dep, {
    req(Deposition())
    Deposition()$dep_plot
  })
  
  output$dep_plot <- renderPlot({
    req(action_dep_plot())
    action_dep_plot()
  })
  
  ## Print all results only when ready
  output$return_part5_results <- renderText({
    req(action_dep_plot())
    return(1) 
  })
  outputOptions(output, "return_part5_results", suspendWhenHidden = FALSE)  
  
  ## Create data for download
  Part5_results <- reactive({
    req(Deposition())
    
    Deposition_data <-
      tibble(Distance = Deposition()$XX,
             Deposition = Deposition()$APplume)
        
    return(Deposition_data)
  })
  
  ## Downloadable csv of data used for plotting 
  output$download.part5.data <- downloadHandler(
    
    filename = function() {
      paste0(
        "Deposition_with_distance_results.csv"
      )
    },
    content = function(file) {
      write.csv(Part5_results(), file, row.names = FALSE)
    }
  )
  
  
  ## Output example data file for user if requested
  output$download.example.DSD.csv <- downloadHandler(
    filename = function() {
      paste("Example.DSD", ".csv", sep="")
    },
    content = function(file) {
      write.csv(Example.DSD, file, row.names=FALSE)
    }
  )
  

}) # End of server script




########################################################################################
## Create Shiny app ----
shinyApp(ui, server)
