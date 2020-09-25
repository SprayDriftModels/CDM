## Initiate environment conditions -- hard-coded; not influenced by the user
########################################################################################

## Check for packages, if not present install
# list.of.packages <- c("shiny",
#                       "shinydashboard",
#                       "nlstools",
#                       "tidyverse",
#                       "ggplot2",
#                       "nleqslv",
#                       "DT",
#                       "shinyjs",
#                       "V8",
#                       "gridExtra",
#                       "deSolve",
#                       "tidyr",
#                       "shinydashboard",
#                       "shinycssloaders",
#                       "magrittr")
# new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
# if(length(new.packages)) install.packages(new.packages, dependencies = TRUE, repos = structure(c(CRAN="http://cloud.r-project.org/")))

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
library(tidyr)
library(shinydashboard)
library(shinycssloaders)
library(magrittr)

## Create functions
`%notin%` <- Negate(`%in%`)

## Create options for canopy/wind speed
MeasurementOptions = c(1, 2)

## Load hard-coded inputs
Nozzle_params <- as_tibble(read.csv("./Constants/Nozzle_Params.csv", header = T))
DDD_params <- as_tibble(read.csv("./Constants/DDD_Params.csv", header = T))

## Load example DSD file
Example.DSD <- read.csv("Templates/DSD_template.csv", header = T)

## Load all functions used
# source("./Rscripts/1_psd_function.R")
# source("./Rscripts/2_wet_bulb_function.R")
# source("./Rscripts/3_wvprofile_params.R")
# source("./Rscripts/4_Nozzle_Characteristics.R")
# source("./Rscripts/4_Droplet_Transport_function.R")
# source("./Rscripts/5_Deposition_Calcs_function.R")
library(Casanova)
source("./Rscripts/debounce_sc.R")

## Set "Driver" -- whether running in shiny or terminal (main)
Driver = "shiny"



##################################################################################
## Set up UI #####################################################################

ui <- dashboardPage(

  skin = "yellow",
  title = "MONDRIFT",

  # HEADER ------------------------------------------------------------------
  dashboardHeader(
    #title = span(img(src = "CBTrust.jpg", height = 50), "BMP Evaluation Tools"),
    title = "MONDRIFT",

    titleWidth = 400
  ),


  # SIDEBAR -----------------------------------------------------------------
  dashboardSidebar(

    width = 400,
    tags$style(HTML(".main-sidebar { font-size: 18px; }")),

    sidebarMenu(

      tags$head(tags$style('h6 {color:#FDE9AD;}')),

      ########
      # Step 1
      menuItem(text = "Step 1: PSD Curve Fitting",
               tabName = "Step_1",
               icon = icon("tint"), #could also use chart-line

               tags$head(
                 tags$style(
                   type = "text/css",
                   ".nav-tabs {font-size: 16px} ",
                   "input:invalid {background-color: #FFCCCC;}" #turn red if entry is invalid
                 )
               ),

               style = "background-color: #FDE9AD; color: #000000", ## choose background color
               tags$style(
                 type = "text/css", ## add css-style to the lists of selected categories and the dropdown menu
                 ".selectize-input { font-size: 12pt; line-height: 13pt;}
                            .selectize-dropdown { font-size: 12pt; line-height: 13pt; }"
               ),

               h6("-"), #used to create space

               ## Parameter selection - part 1
               h3("Input: Select a file"),

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
                 label = "Download example PSD input"),

               h3(""), #used to create space

               actionButton("action_fit_psd", "Fit PSD"),

               h6("-") #used to create space

      ), #End Step_1


      ########
      # Step 2
      menuItem(
        text = "Step 2: Wet Bulb Calculation",
        tabName = "Step_2",
        icon = icon("tint"),

        tags$head(
          tags$style(
            type = "text/css",
            ".nav-tabs {font-size: 16px} ",
            "input:invalid {background-color: #FFCCCC;}" #turn red if entry is invalid
          )
        ),

        style = "background-color: #FDE9AD; color: #000000", ## choose background color
        tags$style(
          type = "text/css", ## add css-style to the lists of selected categories and the dropdown menu
          ".selectize-input { font-size: 12pt; line-height: 13pt;}
                            .selectize-dropdown { font-size: 12pt; line-height: 13pt; }"
        ),

        numericInput(inputId = "Tair",
                     label = "Dry air temperature (Celcius):", # ***Do we want to let them enter in F too? (then convert)
                     #value = "NA",
                     value = "17.689", #*** Debugging purposes
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

        #uiOutput("action_Twb"),  # button to plot output
        actionButton("action_Twb", "Calculate Wet Bulb Temp"),

        h6("-") #used to create space
      ), #End Step_2

      ########
      # Step 3
      menuItem(
        text = "Step 3: Wind Profile Calculation",
        tabName = "Step_3",
        icon = icon("tint"),

        tags$head(
          tags$style(
            type = "text/css",
            ".nav-tabs {font-size: 16px} ",
            "input:invalid {background-color: #FFCCCC;}" #turn red if entry is invalid
          )
        ),

        style = "background-color: #FDE9AD; color: #000000", ## choose background color
        tags$style(
          type = "text/css", ## add css-style to the lists of selected categories and the dropdown menu
          ".selectize-input { font-size: 12pt; line-height: 13pt;}
                            .selectize-dropdown { font-size: 12pt; line-height: 13pt; }"
        ),

        selectizeInput(
          inputId = "NumberMeasures_chosen",
          label = 'Canopy/wind measurements',
          choice = c('Choose number of measurements' = '', MeasurementOptions),
          multiple = FALSE,
          selected = NULL
        ),

        ## Drop-downs for data input depend on Measurements.chosen
        uiOutput("Elevation_wind_speed_1"), #Options 1 and 2
        uiOutput("MPH_wind_speed_1"),   #Options  2 only
        uiOutput("Elevation_wind_speed_2"), #Options 1 and 2
        uiOutput("MPH_wind_speed_2"),   #Options  2 only
        uiOutput("Canopy_height"),  #Options 1 only
        uiOutput("action_wet"),  #plot output

        h6("-") #used to create space
      ), #End Step_3

      ########
      # Step 4
      menuItem(
        text = "Step 4: Droplet Transport Calculations",
        tabName = "Step_4",
        icon = icon("tint"),

        tags$head(
          tags$style(
            type = "text/css",
            ".nav-tabs {font-size: 16px} ",
            "input:invalid {background-color: #FFCCCC;}" #turn red if entry is invalid
          )
        ),

        style = "background-color: #FDE9AD; color: #000000", ## choose background color
        tags$style(
          type = "text/css", ## add css-style to the lists of selected categories and the dropdown menu
          ".selectize-input { font-size: 12pt; line-height: 13pt;}
                            .selectize-dropdown { font-size: 12pt; line-height: 13pt; }"
        ),

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

        actionButton("action_drop_trans", "Calculate Droplet Transport"),

        h6("-") #used to create space
      ), #End Step_4

      ########
      # Step 5
      menuItem(
        text = "Step 5: Calculate Deposition with Distance",
        tabName = "Step_5",
        icon = icon("tint"),

        tags$head(
          tags$style(
            type = "text/css",
            ".nav-tabs {font-size: 16px} ",
            "input:invalid {background-color: #FFCCCC;}" #turn red if entry is invalid
          )
        ),

        style = "background-color: #FDE9AD; color: #000000", ## choose background color
        tags$style(
          type = "text/css", ## add css-style to the lists of selected categories and the dropdown menu
          ".selectize-input { font-size: 12pt; line-height: 13pt;}
                            .selectize-dropdown { font-size: 12pt; line-height: 13pt; }"
        ),

        numericInput(inputId = "IAR",
                     label = "Intended Application Rate (lb/acre):",
                     value = "NA",
                     #value = "0.4996", # Default value
                     step = 0.0000001, #*** How many decimal places do we want?
                     min = 0, #****Is there a good min?
                     max = 100),  #****Is there a good max?

        numericInput(inputId = "xactive",
                     label = "Concentration in tank solution (wtfraction):",
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

        actionButton("action_plot_dep", "Calculate Deposition"),

        h6("-") #used to create space
      ), #End Step_5


      ########
      # Step 6
      menuItem(
        text = "Step 6: Generate Report",
        tabName = "Step_6",
        icon = icon("tint"),

        tags$head(
          tags$style(
            type = "text/css",
            ".nav-tabs {font-size: 16px} ",
            "input:invalid {background-color: #FFCCCC;}" #turn red if entry is invalid
          )
        ),

        style = "background-color: #FDE9AD; color: #000000", ## choose background color
        tags$style(
          type = "text/css", ## add css-style to the lists of selected categories and the dropdown menu
          ".selectize-input { font-size: 12pt; line-height: 13pt;}
                            .selectize-dropdown { font-size: 12pt; line-height: 13pt; }"
        ),

        h6("-"), #used to create space

        downloadButton("report", "Generate report"),

        h6("-") #used to create space
      )

    )
  ),





  ############
  ## Body ----
  dashboardBody(

    tags$head(
      tags$style(type='text/css',
                 ".nav-tabs {font-size: 18px} ")),

    style = "background-color: #ffffff; color: #000000", ## choose background color


    ## Part 1 Results
    fluidRow(
      column(9,
             h2("Results")
      )
    ),

    fluidRow(
      column(12,
             h3("Step 1: PSD Curve Fitting"),

             # Show or hide results depending on whether input values match those used for downstream calculations
             shinyjs::useShinyjs(),
             shinyjs::hidden(
               div(
                 id = "ShowHide_Part_1",

             ## Plot results when ready
             conditionalPanel("input.action_fit_psd",
                              column(9,
                                     align="center",
                                     htmlOutput("Fit_plot_footnote"),
                                     plotOutput('Fit_plot',
                                                dblclick = "plot1_dblclick",
                                                brush = brushOpts(
                                                  id = "plot1_brush",
                                                  resetOnNew = TRUE
                                                ))),
                              column(3,
                                     align = "center",
                                     tableOutput('Part1_table')),
                              tags$style(type='text/css', "#Part1_table { width:100%; margin-top: 100px;}")
             )
      ),
      tags$hr()
             ))
    ),

    ## Part 2 Results
    fluidRow(
      column(12,
             h3("Step 2: Wet Bulb Calculation Results"),

             # Show or hide results depending on whether input values match those used for downstream calculations
             shinyjs::useShinyjs(),
             shinyjs::hidden(
               div(
                 id = "ShowHide_Part_2",

             ## Plot results when ready
             conditionalPanel("input.action_Twb",
                              column(12,
                                     verbatimTextOutput("Twb_values"),
                                     tags$head(tags$style(HTML("
                              #Twb_values {
                                font-size: 16px;
                              }
                              ")))))
      ),
      tags$hr()
             ))
    ),

    ## Part 3 Results
    fluidRow(
      column(12,
             h3("Step 3: Wind Profile Calculation Results"),

             # Show or hide results depending on whether input values match those used for downstream calculations
             shinyjs::useShinyjs(),
             shinyjs::hidden(
               div(
                 id = "ShowHide_Part_3",

             ## Plot results when ready
             conditionalPanel("output.action_wet",
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
             )
      ),
      tags$hr()
             ))
    ),

    ## Part 4 Results
    fluidRow(
            column(12,
             h3("Step 4: Droplet Transport Calculation Results"),

             # Show or hide results depending on whether input values match those used for downstream calculations
             shinyjs::useShinyjs(),
             shinyjs::hidden(
               div(
                 id = "ShowHide_Part_4",

             ## Plot results when ready
             conditionalPanel("input.action_drop_trans",
                              column(4,
                                     tabsetPanel(
                                       id = 'Part4_Table',
                                       tabPanel("Centerline", DT::dataTableOutput("Droplet1.table")),
                                       tabPanel("Downwind", DT::dataTableOutput("Droplet2.table")),
                                       tabPanel("Upwind", DT::dataTableOutput("Droplet3.table")))),
                              column(8,
                                     plotOutput('Part4_plot')),
                              tags$style(type='text/css', "#Part4_plot { width:100%; margin-top: 100px;}"),
             )
      ),
      tags$hr()
             ))
    ),

    ## Part 5 Results
    fluidRow(
      column(12,
             h3("Step 5: Deposition with Distance Calculations Results"),

             # Show or hide results depending on whether input values match those used for downstream calculations
             shinyjs::useShinyjs(),
             shinyjs::hidden(
               div(
                 id = "ShowHide_Part_5",

             ## Plot results when ready (i.e., when output.return_part5_results is created)
             conditionalPanel("input.action_plot_dep",
                              column(12,
                                     plotOutput('dep_plot'))
             )
               )
             )
      )
      # For debugging purposes
      , tableOutput("checker") # a needed output in ui.R, doesn't have to be table
    )
  ) #End Mainpanel
) # End of UI





#########################################################################################################
# Set up server logic
server <- shinyServer(function(input, output, session) {



  ############################################################################################################
  ## PART 1 PSD Curve Fitting


  ## Upload PSD data
  selected.data <- reactive({
    inFile <- input$file1

    if (is.null(inFile)) {
      return(NULL)
    }
    file.chosen <- read_csv(inFile$datapath)

    ## Check that file format is correct - a "Droplet" and at least one "Trial" column
    if(file.chosen %>%
       select(starts_with("Droplet")) %>%
              ncol() == 1 &
       file.chosen %>%
       select(starts_with("Trial")) %>%
       ncol() >= 1) {

      ## Rename Droplet column for later steps
      file.chosen <-
        file.chosen %>%
        rename(Droplet_Size_microns = starts_with("Droplet"))

    } else {
      showNotification("Input file format inccorrect - needs a \"Droplet\" column and one or more \"Trial\" column(s)",
                       type = "error")

      file.chosen <- NULL
    }

    return(file.chosen)
  })



  ## Process input data files
  Data2 <- eventReactive(input$action_fit_psd, {
    req(selected.data())

    ## Calculate mean for however many trials were included
    ymean <- selected.data() %>%
      select(-Droplet_Size_microns) %>%
      apply(.,1,mean)

    ## Determine where to draw the cut-off (begin with first value over zero and end with first value that reaches 100)
    firsty <- min(which(ymean > 0))
    lasty <- max(which(ymean < 100)) + 1

    ## Apply cut-off to y and Dpdata datasets
    y <- ymean %>%
      tibble::enframe() %>%
      slice(firsty:lasty) %>%
      pull(value)

    Dpdata <- selected.data() %>%
      select(Droplet_Size_microns) %>%
      slice(firsty:lasty) %>%
      pull(Droplet_Size_microns)

    Data2 <- list(y = y,
                  Dpdata = Dpdata)

    return(Data2)
  })


  ## Obtain fitted parameters of the drop size distribution model
  pars <- eventReactive(input$action_fit_psd, {
    req(Data2())

    ## Calculate parameters using the loaded function "1a_psd_function.R"
    pars <- try(psd(Data2()$y,
                Data2()$Dpdata),
                silent = TRUE)

    ## Check for errors in curve fitting
    if(is(pars, "try-error")) {
      showNotification("Curve fitting failed, please check that input file is the correct format",
                       type = "error")

      pars.list <- NULL

    } else {
    pars.list <- list(pars = pars,
                  filename = input$file1)
    }

    return(pars.list)
  })


  ## Output Part 1 (using action button to avoid warnings/errors while waiting for user input)

  ## Create reactive to store axes ranges
  ranges <- reactiveValues(x = NULL, y = NULL)

  ## Set axes ranges based on user brush and click
  observeEvent(input$plot1_dblclick, {
    brush <- input$plot1_brush
    if (!is.null(brush)) {
      ranges$x <- c(brush$xmin, brush$xmax)
      ranges$y <- c(brush$ymin, brush$ymax)
    } else {
      ranges$x <- NULL
      ranges$y <- NULL
    }
  })

  ## Plot Curve fit
  observeEvent(input$action_fit_psd,{
    req(pars())

    shinyjs::show("ShowHide_Part_1")

    output$Fit_plot <- renderPlot({
      pars()$pars$plot +
      coord_cartesian(xlim = ranges$x, ylim = ranges$y, expand = FALSE)
    })

    output$Part1_table <- renderTable({
      pars()$pars$table
    })
  })

  output$Fit_plot_footnote <- renderUI({
    HTML(
      paste(
        "Click and drag cursor over plot to select area, double-click to zoom in",
        "Double-click with no selection to revert to standard view",
        sep = '<br/>'
      )
    )
  })

  # ## Reset downstream results if inputs change
  observe({
    req(pars())

    if(pars()$filename != input$file1){
      shinyjs::hide("ShowHide_Part_1")
      shinyjs::hide("ShowHide_Part_2")
      shinyjs::hide("ShowHide_Part_3")
      shinyjs::hide("ShowHide_Part_4")
      shinyjs::hide("ShowHide_Part_5")
    }
  })

  # # Debugging script
  # output$checker <- renderTable({
  #   glimpse(paste0(input$file1$name, pars()$filename$name))
  # })


  ############################################################################################################
  ## PART 2 Wet Bulb Calculation

  # The following contains the wet bulb temperature
  # Inputs are in sequence Dry air temperature (Tair) degrees C, Barometric pressure (Patm) in mmHg abs, and Percent relative humidity (RH)
  # Outputs are: DTwb,Twb

  Twb <- eventReactive(input$action_Twb, {
    req(input$Tair)
    req(input$Patm)
    req(input$RH)
    Twb <- wet_bulb(input$Tair, input$Patm, input$RH)

    Twb_results <-
      list("Twb" = Twb,
           "Tair" = input$Tair,
           "Patm" = input$Patm,
           "RH" = input$RH)

    return(Twb_results)
  })

  ## Output results with button push
  observeEvent(input$action_Twb,{
    shinyjs::show("ShowHide_Part_2")

      output$Twb_values <- renderText({
      paste0("Change in Wet Bulb Temperature (DTwb in °C): ", round(Twb()$Twb[1],2), "\nWet Bulb Temperature (Twb in °C): ", round(Twb()$Twb[2],2))
    })
  })


  # ## Reset downstream results if inputs change
  observe({
    req(Twb())

    if(Twb()$Tair != input$Tair |
       Twb()$Patm != input$Patm |
       Twb()$RH != input$RH){
       shinyjs::hide("ShowHide_Part_2")
       shinyjs::hide("ShowHide_Part_3")
       shinyjs::hide("ShowHide_Part_4")
       shinyjs::hide("ShowHide_Part_5")
      }
  })





  ############################################################################################################
  ## PART 3 Wind Profile

  ##### Elevation
  output$Elevation_wind_speed_1 <- renderUI({
    if (is.null(input$NumberMeasures_chosen))
      return()

    if (input$NumberMeasures_chosen == 1 | input$NumberMeasures_chosen == 2)
      return(
        numericInput(inputId = "Elevation_wind_speed_1",
                     label = "1st Elevation wind speed (ft):", # ***Do we want to let them enter in meters too? (then convert)
                     #value = "NA",
                     value = 10, #*** what to set as default?
                     step = 0.001, #*** How many decimal places do we want?
                     min = 0, #*** Is this correct
                     max = 5000 )) #*** Is there a good max elevation?
  })

  output$Elevation_wind_speed_2 <- renderUI({
    if (is.null(input$NumberMeasures_chosen))
      return()

    if (input$NumberMeasures_chosen == 1)
      return()

    if (input$NumberMeasures_chosen == 2)
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

    if (input$NumberMeasures_chosen == 1 | input$NumberMeasures_chosen == 2)
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

    if (input$NumberMeasures_chosen == 1)
      return()

    if (input$NumberMeasures_chosen == 2)
      return(
        numericInput(inputId = "MPH_wind_speed_2",
                     label = "2nd wind speed (mph):",
                     value = "9.44",
                     step = 0.001, #*** How many decimal places do we want?
                     min = 0,
                     max = 250))
  })

  ##### Canopy height (only used when one set of wind speed and elevation selected)
  output$Canopy_height <- renderUI({
    if (is.null(input$NumberMeasures_chosen))
      return()

    if (input$NumberMeasures_chosen == 2)
      return()

    if (input$NumberMeasures_chosen == 1)
      return(
        numericInput(inputId = "Canopy_height",
                     label = "Canopy_height (in):",
                     value = "4",
                     step = 0.001, #*** How many decimal places do we want?
                     min = 0, #*** Is this 0?
                     max = 5000)) #*** Is there a good max height?
  })

  ##### Calculations
  wvprofile_params <- eventReactive(input$action_wet, {
    req(input$NumberMeasures_chosen)

    if (is.null(input$NumberMeasures_chosen))
      return()

    if (input$NumberMeasures_chosen == 1){
      wvprofile_params <- wvprofile(input$Elevation_wind_speed_1,
                                    input$MPH_wind_speed_1,
                                    input$Canopy_height)
      wvprofile_params_list <-
        list("wvprofile_params" = wvprofile_params,
             "Elevation_wind_speed_1" = input$Elevation_wind_speed_1,
             "MPH_wind_speed_1" = input$MPH_wind_speed_1,
             "Canopy_height" = input$Canopy_height)

      return(wvprofile_params_list)}

    if (input$NumberMeasures_chosen == 2) {
      wvprofile_params <- WV2m(input$Elevation_wind_speed_1,
                               input$Elevation_wind_speed_2,
                               input$MPH_wind_speed_1,
                               input$MPH_wind_speed_2)

      wvprofile_params_list <-
        list("wvprofile_params" = wvprofile_params,
             "Elevation_wind_speed_1" = input$Elevation_wind_speed_1,
             "Elevation_wind_speed_2" = input$Elevation_wind_speed_2,
             "MPH_wind_speed_1" = input$MPH_wind_speed_1,
             "MPH_wind_speed_2" = input$MPH_wind_speed_2)}

      return(wvprofile_params_list)

  })

  ## Create action button
  output$action_wet <- renderUI({
    if (is.null(input$NumberMeasures_chosen)){
      return()
    }

    if (input$NumberMeasures_chosen == 2){
      return(actionButton("action_wet", "Calculate wind profile"))
    }

    if (input$NumberMeasures_chosen == 1){
      return(actionButton("action_wet", "Calculate wind profile"))
    }
  })

  observeEvent(input$action_wet,{
    shinyjs::show("ShowHide_Part_3")

    output$z0_uf <- renderText({
      paste0("Friction height, cm (z0): ", round(wvprofile_params()$wvprofile_params[1],2), "\nFriction velocity, cm/sec (uf): ", round(wvprofile_params()$wvprofile_params[2],2))
    })
  })


  ## Reset downstream results if inputs change
  observe({
    req(wvprofile_params())
    req(input$NumberMeasures_chosen)

    if (is.null(input$NumberMeasures_chosen)){
      return()
    }

    if (input$NumberMeasures_chosen == 1){

      if(is.null(wvprofile_params()$Canopy_height)){
            shinyjs::hide("ShowHide_Part_3")
            shinyjs::hide("ShowHide_Part_4")
            shinyjs::hide("ShowHide_Part_5")
      }else if(wvprofile_params()$Elevation_wind_speed_1 != input$Elevation_wind_speed_1 |
         wvprofile_params()$MPH_wind_speed_1 != input$MPH_wind_speed_1 |
         wvprofile_params()$Canopy_height != input$Canopy_height
        ){
          shinyjs::hide("ShowHide_Part_3")
          shinyjs::hide("ShowHide_Part_4")
          shinyjs::hide("ShowHide_Part_5")
        }
      }


    if(input$NumberMeasures_chosen == 2){

      if(is.null(wvprofile_params()$Elevation_wind_speed_2) |
         is.null(wvprofile_params()$MPH_wind_speed_2)){
            shinyjs::hide("ShowHide_Part_3")
            shinyjs::hide("ShowHide_Part_4")
            shinyjs::hide("ShowHide_Part_5")
      } else if(wvprofile_params()$Elevation_wind_speed_1 != input$Elevation_wind_speed_1 |
         wvprofile_params()$Elevation_wind_speed_2 != input$Elevation_wind_speed_2 |
         wvprofile_params()$MPH_wind_speed_1 != input$MPH_wind_speed_1 |
         wvprofile_params()$MPH_wind_speed_2 != input$MPH_wind_speed_2
        ){
        shinyjs::hide("ShowHide_Part_3")
        shinyjs::hide("ShowHide_Part_4")
        shinyjs::hide("ShowHide_Part_5")
      }
    }
  })



  ############################################################################################################
  ## PART 4 Droplet Transport

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
    req(wvprofile_params())


    ## Hard-coded parameters specific to nozzle used (file can be changed in Constants directory)
    p <- Nozzle_params %>% select(p)
    NF <- Nozzle_params %>% select(NF)
    ddd1 <- DDD_params$ddd1
    ddd2 <- DDD_params$ddd2
    ddd3 <- DDD_params$ddd3

    ## Calculated from previous function
    DTwb <- Twb()$Twb[1] # Wetbulb temperature depression, C
    z0 <- wvprofile_params()$wvprofile_params[1]
    Uf <- wvprofile_params()$wvprofile_params[2]

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


    Droplet_Transport_Results.list <-
      list("droplet_1" = droplet_1,
           "droplet_2" = droplet_2,
           "droplet_3" = droplet_3,
           "Tair" = input$Tair,
           "RH" = input$RH,
           "rhow" = input$rhow,
           "rhos" = input$rhos,
           "xs0" = input$xs0,
           "H0" = input$H0,
           #"DTTwb" = DTwb,
           "hcm" = input$hcm,
           #"Uf" = Uf,
           #"z0" = z0,
           "app_p" = input$app_p,
           "angle" = input$angle,
           "rhosoln" = input$rhosoln)

    return(Droplet_Transport_Results.list)

  })


  ## Output from Part 4

  observeEvent(input$action_drop_trans,{

    shinyjs::show("ShowHide_Part_4")

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

      #***SFR
      if (input$action_drop_trans == 0) {
        return(NULL)
      }

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

  }) # ObserveEvent


  ## Reset downstream results if inputs change
  observe({
    req(Droplet_Transport_Results())

    if(Droplet_Transport_Results()$rhow != input$rhow |
       Droplet_Transport_Results()$rhos != input$rhos |
       Droplet_Transport_Results()$xs0 != input$xs0 |
       Droplet_Transport_Results()$H0 != input$H0 |
       Droplet_Transport_Results()$hcm != input$hcm |
       Droplet_Transport_Results()$app_p != input$app_p |
       Droplet_Transport_Results()$angle != input$angle |
       Droplet_Transport_Results()$rhosoln != input$rhosoln
       )
      {
      shinyjs::hide("ShowHide_Part_4")
      shinyjs::hide("ShowHide_Part_5")
      }
  })



  ############################################################################################################
  ## PART 5 Deposition Calculations

  Deposition <- eventReactive(input$action_plot_dep, {

    # if (input$action_plot_dep == 0)
    #   return()

    req(pars()$pars)
    req(Droplet_Transport_Results())
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
    a <- unname(pars()$pars$res)
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



    Deposition_Results.list <-
      list("Deposition" = Deposition,
           "IAR" = input$IAR,
           "xactive" = input$xactive,
           "FD" = input$FD,
           "PL" = input$PL,
           "NozzleSpacing" = input$NozzleSpacing,
           "psipsipsi" = input$psipsipsi,
           "rhol" = rhoL,
           "Cent" = Cent,
           "Dwnd" = Dwnd,
           "Uwnd" = Uwnd,
           "Dpmax" = input$Dpmax,
           "DDpmin" = input$DDpmin,
           #"a" = a,
           "MMM" = input$MMM,
           "lambda_res" = input$lambda_res,
           "rhosoln" = input$rhosoln)

    return(Deposition_Results.list)
  })

  observeEvent(input$action_plot_dep,{
    shinyjs::show("ShowHide_Part_5")

    output$dep_plot <- renderPlot({
      Deposition()$Deposition$dep_plot
    })
  })

  ## Reset downstream results if inputs change
  observe({
    req(Deposition())

    if(Deposition()$IAR != input$IAR |
       Deposition()$xactive != input$xactive |
       Deposition()$FD != input$FD |
       Deposition()$PL != input$PL |
       Deposition()$NozzleSpacing != input$NozzleSpacing |
       Deposition()$psipsipsi != input$psipsipsi |
       Deposition()$Dpmax != input$Dpmax |
       Deposition()$DDpmin != input$DDpmin |
       Deposition()$MMM != input$MMM |
       Deposition()$lambda_res != input$lambda_res
    )
    {
      shinyjs::hide("ShowHide_Part_4")
      shinyjs::hide("ShowHide_Part_5")
    }
  })


  ############################################################################################################
  ## PART 6 Report

  output$report <- downloadHandler(
    # For PDF output, change this to "report.pdf"
    filename = "report.html",
    content = function(file) {
      # Copy the report file to a temporary directory before processing it, in
      # case we don't have write permissions to the current working dir (which
      # can happen when deployed).
      tempReport <- file.path(tempdir(), "report.Rmd")
      file.copy("report.Rmd", tempReport, overwrite = TRUE)

      ## Set up parameters to pass to Rmd document
      # Create table of paramaeters used


      input_params <- tibble("Dry air temperature" = Twb()$Tair,
                             "Barometric pressure" = Twb()$Patm,
                             "Relative humidity" = Twb()$RH,

                             "Number of wind measurements" = as.numeric(input$NumberMeasures_chosen),
                             "Elevation of wind speed (1)" = wvprofile_params()$Elevation_wind_speed_1,
                             "MPH wind speed (1)" = wvprofile_params()$MPH_wind_speed_1,

                             "Density of pure water in droplet" = Droplet_Transport_Results()$rhow,
                             "Density of dissolved solids in droplet" = Droplet_Transport_Results()$rhos,
                             "Mass fraction total dissolved solids in solution" = Droplet_Transport_Results()$xs0,
                             "Height of nozzle above ground" = Droplet_Transport_Results()$H0,
                             "Canopy height (Droplet Transport Calculation)" = Droplet_Transport_Results()$hcm,
                             "Nozzle pressure" = Droplet_Transport_Results()$app_p,
                             "Nozzle angle" = Droplet_Transport_Results()$angle,
                             "Mix density" = Droplet_Transport_Results()$rhosoln,

                             "Intended Application Rate" = Deposition()$IAR,
                             "Conc in tank solution" = Deposition()$xactive,
                             "Downwind field depth" = Deposition()$FD,
                             "Crosswind field width" = Deposition()$PL,
                             "Space between nozzles on Boom" = Deposition()$NozzleSpacing,
                             "Horizontal variation in wind direction around mean direction, 1 stdev" = Deposition()$psipsipsi,
                             "Dpmax" = Deposition()$Dpmax,
                             "Dpmin" = Deposition()$DDpmin,
                             "Number of droplet size bins" = Deposition()$MMM,
                             "Resolution of deposition calculations" = Deposition()$lambda_res
                             )

      #*** add sort to each of these after pivot
      if(input$NumberMeasures_chosen == 1){
        input_params <- input_params %>%
          mutate("Canopy height" = wvprofile_params()$Canopy_height) %>%
          pivot_longer(everything(),
                       names_to = "Parameters",
                       values_to = "Value")
      }

      if(input$NumberMeasures_chosen == 2){
        input_params <- input_params %>%
          mutate("Elevation of wind speed (2)" = wvprofile_params()$Elevation_wind_speed_2,
                 "MPH wind speed (2)" = wvprofile_params()$MPH_wind_speed_2) %>%
          pivot_longer(everything(),
                       names_to = "Parameters",
                       values_to = "Value")
      }


      param_units <- tibble("Dry air temperature" = "Celcius",
                            "Barometric pressure" = "mmHg abs",
                            "Relative humidity" = "%",
                            "Number of wind measurements" = "NA",
                            "Elevation of wind speed (1)" = "ft",
                            "MPH wind speed (1)" = "mph",
                            "Elevation of wind speed (2)" = "ft",
                            "MPH wind speed (2)" = "mph",
                            "Density of pure water in droplet" = "g/cm3",
                            "Density of dissolved solids in droplet" = "g/cm3",
                            "Mass fraction total dissolved solids in solution" = "NA",
                            "Height of nozzle above ground" = "in",
                            "Canopy height" = "cm",
                            "Nozzle pressure" = "psi",
                            "Nozzle angle" = "degrees",
                            "Mix density" = "kg/m3",
                            "Intended Application Rate" = "lb/acre",
                            "Conc in tank solution" = "wtfraction",
                            "Downwind field depth" = "ft",
                            "Crosswind field width" = "ft",
                            "Space between nozzles on Boom" = "in",
                            "Horizontal variation in wind direction around mean direction, 1 stdev" = "degrees",
                            "Dpmax" = "µm",
                            "Dpmin" = "µm",
                            "Number of droplet size bins" = "MMM",
                            "Resolution of deposition calculations" = "NA"
                            ) %>%
                      pivot_longer(everything(),
                                   names_to = "Parameters",
                                   values_to = "Units")


      input_params_units <- left_join(x = input_params,
                y = param_units,
                by = "Parameters")


      params <- list(input_filename = pars()$filename$name,
                     input_params = input_params_units,
                     step1_results_plot = pars()$pars$plot,
                     step1_results_table = pars()$pars$table,
                     step2_results = Twb(),
                     step3_results = wvprofile_params()$wvprofile_params,
                     step4_results = Droplet_Transport_Results(),
                     step5_results = Deposition()$Deposition
      )

      # Knit the document, passing in the `params` list, and eval it in a
      # child of the global environment (this isolates the code in the document
      # from the code in this app).
      rmarkdown::render(tempReport, output_file = file,
                        params = params,
                        envir = new.env(parent = globalenv())
      )
    }
  )


  ############################################################################################################
  ## Supplemental


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
