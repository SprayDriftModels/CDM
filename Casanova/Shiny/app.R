
## Libraries ##

library(shiny)
library(shinydashboard)
library(tidyverse)
library(shinymaterial)
library(rmarkdown)
library(scales)
library(quantreg)
library(shinyjs)
library(shinyWidgets)
library(Casanova)
library(DT)
library(shinyalert)

## Set Driver
driver = "shiny"

## Load units and default values used for each system
# Default_values_units <- read_csv("default/Default_values_units.csv", locale = readr::locale(encoding = "ISO-8859-1")) #need to set encoding to deal with µ

## Load scenario files
#*** may want to store these differently
Params_Germany <- read_csv("default/testing/Params_Germany.csv", locale = readr::locale(encoding = "ISO-8859-1")) #need to set encoding to deal with µ
Params_Spain <- read_csv("default/testing/Params_Spain.csv", locale = readr::locale(encoding = "ISO-8859-1")) #need to set encoding to deal with µ
Params_USA <- read_csv("default/testing/Params_USA.csv", locale = readr::locale(encoding = "ISO-8859-1")) #need to set encoding to deal with µ


#***SFR could instead add these to the R package and load
Wind_Temperature_English_template <- read_csv("../sample_data/Wind_Temperature (English).csv") #need to set encoding to deal with µ
Wind_Temperature_Metric_template <- read_csv("../sample_data/Wind_Temperature (Metric).csv") #need to set encoding to deal with µ

#***SFR could instead add these to the R package and load
DDDData_default <- read_csv("../sample_data/DDD_Params.csv", col_types = 'ddd')

#***SFR could instead add these to the R package and load
DSDData <- read.csv("../sample_data/DSD.csv")


## Currently sourcing these but could add to R package
source("../R/create_paramsData.R")
source("../R/check_units.R")
source("../R/create_params_ui.R")

# #***SFR could instead add these to the R package and load
paramsWT_English <- read.csv("../sample_data/Wind_Temperature (English).csv")
# paramsWT_Metric <- read.csv("../sample_data/Wind_Temperature (Metric).csv")


## Color choices from here: https://materializecss.com/color.html

#### UI for Shiny App ####
ui <- material_page(
  useShinyalert(),  # Set up shinyalert
  title = "Casanova Drift Model (CDM)",
  nav_bar_color =  "green lighten-1",
  background_color = "green lighten-4",
  include_fonts = TRUE,
  include_icons = TRUE,

  material_side_nav(
    fixed = TRUE,
    shiny::tags$li(
      a(
        href = 'https://www.bayer.com/en/',
        img(
          src = "Bayer_logo.png",
          height = "40px",
          .noWS = "outside"
        ),
        style = "padding-top:5px; padding-bottom:5px",
        target = "_blank"
      ),
      class = "dropdown"
    ),
    tags$br(),
    material_side_nav_tabs(
      side_nav_tabs = c(
        "User Guide" = "user_guide",
        "Data Input" = "user_data_input",
        "Calculate" = "calculate",
        "Output" = "output",
        "Advanced" = "advanced"
      ),
      ## For list of icons see -- https://materializecss.com/icons.html
      icons = c("book", "settings", "computer", "blur_on", "extension")
      # color = "blue",
      # font_color = "green"
    )
  ),
  material_side_nav_tab_content(side_nav_tab_id = "user_guide",
                                material_row(
                                  material_column(
                                    width =10,
                                    offset = 1,
                                    material_card(
                                      includeMarkdown("CDM_user_guide.Rmd")
                                    )
                                  )
                                )
  ),
  material_side_nav_tab_content(side_nav_tab_id = "user_data_input",
                                material_row(
                                  offset = 1,
                                  material_column(width = 12,
                                                  offset = 0.5,

                                                  ## Reset all inputs button
                                                  material_card(
                                                    actionBttn(inputId = "reset",
                                                               label = "Reset Everything",
                                                               color = "danger")
                                                  ),

                                                  ## Name Scenario
                                                  material_card(
                                                    title = "Name of scenario",
                                                    uiOutput('name_scenario_ui')
                                                  ),

                                                  ## Load Scenario
                                                  material_card(
                                                    width = 12,
                                                    title = "Construct Dataset",
                                                    material_row(
                                                      material_column(
                                                        width = 3,
                                                    uiOutput('choose_params_dataset_ui'),
                                                    uiOutput('load_params_data_ui')
                                                      ),
                                                    material_column(
                                                      width = 3,
                                                      uiOutput('choose_WTparams_dataset_ui'),
                                                      uiOutput('load_WTparams_data_ui')
                                                    ),
                                                    material_column(
                                                    width = 3,
                                                    uiOutput('choose_DSD_dataset_ui'),
                                                    uiOutput('load_DSD_data_ui')
                                                    ),
                                                    material_column(
                                                    width = 3,
                                                    uiOutput('choose_DDD_dataset_ui'),
                                                    uiOutput('load_DDD_data_ui')
                                                  )
                                                    )
                                                  ),

                                                  material_card(
                                                    material_row(
                                                      material_column(
                                                        width = 8,
                                                        material_card(
                                                          depth = 0,
                                                          divider = F,
                                                          title = "Manually Input or Edit Parameters",
                                                        )
                                                      )
                                                      #***SFR this can be added in next itteration of the app
                                                      # ,
                                                      # material_column(
                                                      #   width = 4,
                                                      #   material_card(
                                                      #     # title = "",
                                                      #     depth = 0,
                                                      #     #*** put save to file here
                                                      #     downloadBttn(outputId = "download_created_params_file",
                                                      #                  label = "Download parameters to file",
                                                      #                  color = "primary")
                                                      #   )
                                                      # )
                                                    ),
                                                    ## Row for all variables
                                                    material_row(

                                                      ## Column for just Environmental variables
                                                      material_column(
                                                        width = 4,
                                                        material_card(
                                                          title = "Environmental Settings",
                                                          depth = 1,
                                                          material_row(
                                                            material_column(
                                                              width = 12,
                                                              uiOutput("env_ui")
                                                            )
                                                          )
                                                        ),
                                                        material_card(
                                                          title = "Wind/temperature profile",
                                                          depth = 1,
                                                          material_row(
                                                            material_column(
                                                              width = 12,
                                                              uiOutput("windtemp_ui"),
                                                              DTOutput('x1')
                                                            )
                                                          )
                                                        )
                                                      ),

                                                      ## Column for just Environmental variables
                                                      material_column(
                                                        width = 8,
                                                        material_card(
                                                          title = "Application Settings",
                                                          depth = 1,
                                                          material_row(
                                                            material_column(
                                                              width = 6,
                                                              uiOutput("droplet_ui")
                                                            ),
                                                            material_column(
                                                              width = 6,
                                                              uiOutput("deposition_ui")
                                                            )
                                                          )
                                                        )
                                                      )
                                                    ),

                                                    material_row(
                                                      material_column(
                                                        width = 12,
                                                        tableOutput("contents"),
                                                        tableOutput("contents2")

                                                      )
                                                    )
                                                  )
                                  ),
                                )
  ),
  material_side_nav_tab_content(side_nav_tab_id = "calculate",
                                material_row(
                                  width = 5,
                                  offset = 1,
                                  material_column(
                                    # actionButton("generate", "Perform calculations and generate Results")
                                    material_button(
                                      "generate",
                                      "Perform calculations and generate Results",
                                      icon = "offline_bolt",
                                      depth = 3,
                                      color = "light-blue accent-1"
                                    )
                                  )
                                )
  ),
  material_side_nav_tab_content(side_nav_tab_id = "output",
                                material_card(depth = 1,
                                              downloadButton("report_download", "HTML report"),
                                              uiOutput('md_file')
                                              )
                                ),
  material_side_nav_tab_content(side_nav_tab_id = "advanced",
                                material_row(),
                                material_row(
                                  material_column(
                                    width = 10,
                                    offset = 1,
                                    plotOutput("Aq_distance_conc_plot")
                                  )
                                )
  )

)

##################################################################################
#### Server function ####
##################################################################################
server <- function(input, output, session) {

  #####
  # Set state of file so they can be set to NULL if reset button pressed
  #borrowed from https://stackoverflow.com/questions/44203728/how-to-reset-a-value-of-fileinput-in-shiny
  #***SFR not currently working

      ## params
      paramsvalues <- reactiveValues(
        upload_state = NULL
      )

      observeEvent(input$params_file_name, {
        paramsvalues$upload_state <- 'uploaded'
      })

      observeEvent(input$reset, {
        paramsvalues$upload_state <- 'reset'
      })

      ## paramsWT
      paramsWTvalues <- reactiveValues(
        upload_state = NULL
      )

      observeEvent(input$paramsWT_file_name, {
        paramsWTvalues$upload_state <- 'uploaded'
      })

      observeEvent(input$reset, {
        paramsWTvalues$upload_state <- 'reset'
      })

      ## DSD
      DSDvalues <- reactiveValues(
        upload_state = NULL
      )

      observeEvent(input$DSD_file_name, {
        DSDvalues$upload_state <- 'uploaded'
      })

      observeEvent(input$reset, {
        DSDvalues$upload_state <- 'reset'
      })

      ## DDD
      DDDvalues <- reactiveValues(
        upload_state = NULL
      )

      observeEvent(input$DDD_file_name, {
        DDDvalues$upload_state <- 'uploaded'
      })

      observeEvent(input$reset, {
        DDDvalues$upload_state <- 'reset'
      })

  #####
  ## Create UI for naming scenario
  output$name_scenario_ui <- renderUI({
    input$reset # reset button

    textInput(inputId = "Scenario_ID",
              label = NULL,
              value = "Name of scenario")

  })


  #####
  ## Select from existing scenarios
  output$choose_params_dataset_ui <- renderUI({
    input$reset # reset button

    ## material_dropdown does not reset correctly so using selectInput
    selectInput(
      inputId = "selected_params_dataset",
      label = "Choose params dataset",
      choices = c("Example Metric",
                  "Example Imperial",
                  "Regulatory Scenarios",
                  "Upload file"),
      selected = "Example Metric",
      selectize = TRUE,
      multiple = FALSE
    )

  })

  output$choose_WTparams_dataset_ui <- renderUI({
    input$reset # reset button

    ## material_dropdown does not reset correctly so using selectInput
    tagList(
      selectInput(
        inputId = "selected_WTparams_dataset",
        label = "Choose wind/temp params dataset",
        choices = c("Build your own",
                    "Upload file"),
        selected = "Example Metric",
        selectize = TRUE,
        multiple = FALSE
      )
    )

  })

  output$choose_DSD_dataset_ui <- renderUI({
    input$reset # reset button

    ## material_dropdown does not reset correctly so using selectInput
    tagList(
      selectInput(
        inputId = "selected_DSD_dataset",
        label = "Choose DSD dataset",
        choices = c("Example DSD",
                    "Upload file"),
        selected = "Example DSD",
        selectize = TRUE,
        multiple = FALSE
      )
    )

  })

  output$choose_DDD_dataset_ui <- renderUI({
    input$reset # reset button

    ## material_dropdown does not reset correctly so using selectInput
    tagList(
      selectInput(
        inputId = "selected_DDD_dataset",
        label = "Choose DDD dataset",
        choices = c("Example DDD",
                    "Upload file"),
        selected = "Example",
        selectize = TRUE,
        multiple = FALSE
      )
    )

  })

  #####
  ## Create UI for selecting type of dataset to use
  output$load_params_data_ui <- renderUI({
    input$reset # reset button
    req(input$selected_params_dataset)

    create_params_ui(selected_dataset = input$selected_params_dataset,
                     type_ui = "params")
  })

  output$load_WTparams_data_ui <- renderUI({
    input$reset # reset button
    req(input$selected_WTparams_dataset)

    create_params_ui(selected_dataset = input$selected_WTparams_dataset,
                     type_ui = "paramsWT")
  })

  output$load_DSD_data_ui <- renderUI({
    input$reset # reset button
    req(input$selected_DSD_dataset)

    create_params_ui(selected_dataset = input$selected_DSD_dataset,
                     type_ui = "DSD")

  })

  output$load_DDD_data_ui <- renderUI({
    input$reset # reset button
    req(input$selected_DDD_dataset)

    create_params_ui(selected_dataset = input$selected_DDD_dataset,
                     type_ui = "DDD")
  })

  #####
  ## User Inputs for params_data
  output$env_ui <- renderUI({
    req(params_data())

    params_data <- params_data()$data

    ## Input dry air temp
    tagList(
      useShinyjs(),
        numericInput(
          inputId = "Tair",
          label = paste0("Dry air temperature (", params_data[params_data$Type == "Tair", "Units"], "):"),
          value = as.numeric(params_data[params_data$Type == "Tair", 4]),
          step = 0.001,
          min = -50,
          max = 50
        ),
        ## Input Barometric pressure, mmHg abs
        numericInput(
          inputId = "Patm",
          label = paste0("Barometric pressure (", params_data[params_data$Type == "Patm", "Units"], "):"),
          value = as.numeric(params_data[params_data$Type == "Patm", 4]),
          step = 0.001,
          min = 300,
          #***Is there a good min? https://www.avs.org/AVS/files/c7/c7edaedb-95b2-438f-adfb-36de54f87b9e.pdf
          max = 800
        ),
        ## Input Percent Relative Humidity
        numericInput(
          inputId = "RH",
          label = paste0("Relative humidity (", params_data[params_data$Type == "RH", "Units"], "):"),
          value = as.numeric(params_data[params_data$Type == "RH", 4]),
          step = 0.001,
          min = 0,
          max = 100
        ),
      ## Input Crop Height
      numericInput(
        inputId = "ch",
        label = paste0("Crop height (", params_data[params_data$Type == "ch", "Units"], "):"),
        value = as.numeric(params_data[params_data$Type == "ch", 4]),
        step = 0.001,
        min = 0,
        max = 100
      )
    )

  })

  #####
  ## User Inputs for paramsWT
  output$windtemp_ui <- renderUI({
    req(input$selected_WTparams_dataset)
    req(params_data)

    params_data <- params_data()$data

    if (input$selected_WTparams_dataset == "Upload file") {
      measurements <- paramsWT_file() %>% select(c(1)) %>% na.omit() %>% nrow() %>% as.integer()
    } else if (input$selected_WTparams_dataset == "Build your own") {
      measurements <- 1
    }
    ## Input Number of Measurements to use
    tagList(
      useShinyjs(),
      numericInput(
        inputId = "WTmeasurements",
        label = 'Max number of wind/temp measurements',
        value = measurements,
        step = 1,
        min = 1,
        max = Inf # limit for this?
      ),
      selectInput(
        inputId = "psipsipsi_method",
        label = paste0("Select method to estimate psipsipsi.\n(Only applies if more than one measurement)"),
        choices = c(1, 2),
        selected = as.numeric(params_data[params_data$Type == "psipsipsi_method", 4])
      )
    )
  })



  ## Create intermediate filename that can be reset (original remains cached)
  WTfile_input <- reactive({
    if (is.null(paramsWTvalues$upload_state)) {
      return(NULL)
    } else if (paramsWTvalues$upload_state == 'uploaded') {
      return(input$paramsWT_file_name)
    } else if (paramsWTvalues$upload_state == 'reset') {
      return(NULL)
    }
  })

  #####
  ## Upload paramsWT file
  paramsWT_file <- reactive({
    req(input$selected_WTparams_dataset)
    input$reset

    if (input$selected_WTparams_dataset == "Upload file") {
      req(WTfile_input())
        inFile <- WTfile_input()
        paramsWT_file <- as.data.frame(read_csv(inFile$datapath, locale = readr::locale(encoding = "ISO-8859-1"), col_types='dddd'))
      #***SFR add validation step
    } else if (input$selected_WTparams_dataset == "Build your own") {
      paramsWT_file = paramsWT_English
    }

    return(paramsWT_file)

  })

  #####
  ## Create WT dataset for UI
  paramsWT <- reactive({
    req(input$WTmeasurements)
    req(input$selected_WTparams_dataset)
    input$reset

    ## If wind_temp file not uploaded
    if (input$selected_WTparams_dataset == "Build your own") {

      paramsWT <-
        data.frame(
          "zx" = as.numeric(rep(NA, input$WTmeasurements)),
          "u" = as.numeric(rep(NA, input$WTmeasurements)),
          "zt" = as.numeric(rep(NA, input$WTmeasurements)),
          "T" = as.numeric(rep(NA, input$WTmeasurements))
      )

      # Encoding(colnames(paramsWT)) <- "ISO-8859-1"
      return(paramsWT)

    } else {
      paramsWT <- paramsWT_file()

      ## Adjust the number of rows based on user input
      if (input$WTmeasurements > nrow(paramsWT)) {
        extra_rows <- input$WTmeasurements - nrow(paramsWT)
        paramsWT[nrow(paramsWT)+1:extra_rows, ] <- NA
      } else if (input$WTmeasurements < nrow(paramsWT)) {
        paramsWT <- paramsWT[1:input$WTmeasurements, ]
      }
      return(paramsWT)
    }

  })


  #####
  ## Create editable WT table
  paramsWT_reactive <- reactiveValues(data = NULL)
  observe({
    paramsWT_reactive$data <- paramsWT()
  })

  proxy = dataTableProxy('x1')

  observeEvent(input$x1_cell_edit, {
    info = input$x1_cell_edit
    str(info)
    i = info$row
    j = info$col
    v = info$value
    paramsWT_reactive$data[i, j] <- DT::coerceValue(v, paramsWT_reactive$data[i, j])
    replaceData(proxy, paramsWT_reactive$data, resetPaging = FALSE)
  })

  output$x1 = DT::renderDT(paramsWT_reactive$data, class = 'cell-border stripe', options = list(lengthChange = FALSE, dom = 't'), selection = 'none', editable = TRUE)
  #####




  #####
  ## Create intermediate filename that can be reset (original remains cached)
  DSDfile_input <- reactive({
    if (is.null(DSDvalues$upload_state)) {
      return(NULL)
    } else if (DSDvalues$upload_state == 'uploaded') {
      return(input$DSD_file_name)
    } else if (DSDvalues$upload_state == 'reset') {
      return(NULL)
    }
  })

  #####
  ## Upload DSD file
  DSD_data <- reactive({
    req(input$selected_DSD_dataset)
    input$reset

    if (input$selected_DSD_dataset == "Example DSD") {
      DSD_data = DSDData
    } else if (input$selected_DSD_dataset == "Upload file") {
      req(DSDfile_input())
      inFile <- DSDfile_input()
      inFile <- input$DSD_file_name
      DSD_data <- as.data.frame(read_csv(inFile$datapath, locale = readr::locale(encoding = "ISO-8859-1")))
      #***SFR add validation step
    }
    return(DSD_data)

  })




  #####
  ## Create intermediate filename that can be reset (original remains cached)
  DDDfile_input <- reactive({
    if (is.null(DDDvalues$upload_state)) {
      return(NULL)
    } else if (DDDvalues$upload_state == 'uploaded') {
      return(input$DDD_file_name)
    } else if (DDDvalues$upload_state == 'reset') {
      return(NULL)
    }
  })

  #####
  ## Upload DDD file
  DDD_data <- reactive({
    req(input$selected_DDD_dataset)
    input$reset

    if (input$selected_DDD_dataset == "Example DDD") {
      DDD_data = DDDData_default
    } else if (input$selected_DDD_dataset == "Upload file") {
      req(DDDfile_input())
      inFile <- DDDfile_input()
      inFile <- input$DDD_file_name
      DDD_data <- as.data.frame(read_csv(inFile$datapath, locale = readr::locale(encoding = "ISO-8859-1")))
      #***SFR add validation step
    }
    return(DDD_data)

  })











  ##### Droplet data info
  output$droplet_ui <- renderUI({
    req(params_data())
    input$reset

    params_data <- params_data()$data

    if (input$selected_params_dataset != "Regulatory Scenarios") {
      tagList(
        numericInput(inputId = "rhow",
                     label = paste0("Density of pure water in droplet (", params_data[params_data$Type == "rhow", "Units"], "):"),
                     value = as.numeric(params_data[params_data$Type == "rhow", 4]),
                     step = 0.001,
                     min = 0,
                     max = 1),

        numericInput(inputId = "rhos",
                     label = paste0("Density of dissolved solids in droplet (", params_data[params_data$Type == "rhos", "Units"], "):"),
                     value = as.numeric(params_data[params_data$Type == "rhos", 4]),
                     step = 0.001,
                     min = 0,
                     max = 100),

        numericInput(inputId = "xs0",
                     label = "Mass fraction total dissolved solids in solution:",
                     value = as.numeric(params_data[params_data$Type == "xs0", 4]),
                     step = 0.000001,
                     min = 0,
                     max = 1),

        numericInput(inputId = "H0",
                     label = paste0("Height of nozzle above ground (", params_data[params_data$Type == "H0", "Units"], "):"),
                     value = as.numeric(params_data[params_data$Type == "H0", 4]),
                     step = 0.001,
                     min = 0,
                     max = 1000),

        numericInput(inputId = "hcm",
                     label = paste0("Canopy height (", params_data[params_data$Type == "hcm", "Units"], "):"),
                     value = as.numeric(params_data[params_data$Type == "hcm", 4]),
                     step = 0.001,
                     min = 0,
                     max = 1000),

        numericInput(inputId = "app_p",
                     label = paste0("Nozzle pressure (", params_data[params_data$Type == "app_p", "Units"], "):"),
                     value = as.numeric(params_data[params_data$Type == "app_p", 4]),
                     step = 0.001,
                     min = 0,
                     max = 1000),

        numericInput(inputId = "angle",
                     label = paste0("Nozzle angle (", params_data[params_data$Type == "angle", "Units"], "):"),
                     value = as.numeric(params_data[params_data$Type == "angle", 4]),
                     step = 0.001,
                     min = 0,
                     max = 360),

        numericInput(inputId = "rhosoln",
                     label = paste0("Mix density (", params_data[params_data$Type == "rhosoln", "Units"], "):"),
                     value = as.numeric(params_data[params_data$Type == "rhosoln", 4]),
                     step = 0.001,
                     min = 0,
                     max = 10000)
      )
    } else {
      disabled(    tagList(
        numericInput(inputId = "rhow",
                     label = paste0("Density of pure water in droplet (", params_data[params_data$Type == "rhow", "Units"], "):"),
                     value = as.numeric(params_data[params_data$Type == "rhow", 4]),
                     step = 0.001,
                     min = 0,
                     max = 1),

        numericInput(inputId = "rhos",
                     label = paste0("Density of dissolved solids in droplet (", params_data[params_data$Type == "rhos", "Units"], "):"),
                     value = as.numeric(params_data[params_data$Type == "rhos", 4]),
                     step = 0.001,
                     min = 0,
                     max = 100),

        numericInput(inputId = "xs0",
                     label = "Mass fraction total dissolved solids in solution:",
                     value = as.numeric(params_data[params_data$Type == "xs0", 4]),
                     step = 0.000001,
                     min = 0,
                     max = 1),

        numericInput(inputId = "H0",
                     label = paste0("Height of nozzle above ground (", params_data[params_data$Type == "H0", "Units"], "):"),
                     value = as.numeric(params_data[params_data$Type == "H0", 4]),
                     step = 0.001,
                     min = 0,
                     max = 1000),

        numericInput(inputId = "hcm",
                     label = paste0("Canopy height (", params_data[params_data$Type == "hcm", "Units"], "):"),
                     value = as.numeric(params_data[params_data$Type == "hcm", 4]),
                     step = 0.001,
                     min = 0,
                     max = 1000),

        numericInput(inputId = "app_p",
                     label = paste0("Nozzle pressure (", params_data[params_data$Type == "app_p", "Units"], "):"),
                     value = as.numeric(params_data[params_data$Type == "app_p", 4]),
                     step = 0.001,
                     min = 0,
                     max = 1000),

        numericInput(inputId = "angle",
                     label = paste0("Nozzle angle (", params_data[params_data$Type == "angle", "Units"], "):"),
                     value = as.numeric(params_data[params_data$Type == "angle", 4]),
                     step = 0.001,
                     min = 0,
                     max = 360),

        numericInput(inputId = "rhosoln",
                     label = paste0("Mix density (", params_data[params_data$Type == "rhosoln", "Units"], "):"),
                     value = as.numeric(params_data[params_data$Type == "rhosoln", 4]),
                     step = 0.001,
                     min = 0,
                     max = 10000)
      ))
    }
  })




  ##### Deposition data info
  output$deposition_ui <- renderUI({
    req(params_data())
    input$reset

    # Validate units
    validate(
      need(check_units(paramsUnits = params_data()$units,
                       paramsData = params_data()$data,
                       driver = "shiny") != "FAIL", "Units must be in metric or English (imperial) system; see Casanova::params_metric and Casanova::params_english for how data should be formatted")
    )

    params_data <- params_data()$data

    if (input$selected_params_dataset != "Regulatory Scenarios") {
      tagList(
        numericInput(inputId = "IAR",
                     label = paste0("Intended Application Rate (", params_data[params_data$Type == "IAR", "Units"], "):"),
                     value = as.numeric(params_data[params_data$Type == "IAR", 4]),
                     step = 0.0000001,
                     min = 0,
                     max = 100),
        numericInput(inputId = "xactive",
                     label = paste0("Concentration in tank solution (", params_data[params_data$Type == "xactive", "Units"], "):"),
                     value = as.numeric(params_data[params_data$Type == "xactive", 4]),
                     step = 0.0000001,
                     min = 0,
                     max = 1),

        numericInput(inputId = "FD",
                     label = paste0("Downwind field depth (", params_data[params_data$Type == "FD", "Units"], "):"),
                     value = as.numeric(params_data[params_data$Type == "FD", 4]),
                     step = 0.001,
                     min = 0,
                     max = 10000),

        numericInput(inputId = "PL",
                     label = paste0("Crosswind field width (", params_data[params_data$Type == "PL", "Units"], "):"),
                     value = as.numeric(params_data[params_data$Type == "PL", 4]),
                     step = 0.001,
                     min = 0,
                     max = 10000),

        numericInput(inputId = "NozzleSpacing",
                     label = paste0("Space between nozzles on Boom (", params_data[params_data$Type == "NozzleSpacing", "Units"], "):"),
                     value = as.numeric(params_data[params_data$Type == "NozzleSpacing", 4]),
                     step = 0.001,
                     min = 0,
                     max = 100),

        numericInput(inputId = "psipsipsi",
                     label = paste0("Horizontal variation in wind direction around mean direction, 1 stdev (", params_data[params_data$Type == "psipsipsi", "Units"], "):"),
                     value = as.numeric(params_data[params_data$Type == "psipsipsi", 4]),
                     step = 0.001,
                     min = 0,
                     max = 100),

        numericInput(inputId = "MMM",
                     label = paste0("Number of droplet size bins (", params_data[params_data$Type == "MMM", "Units"], "):"),
                     value = as.numeric(params_data[params_data$Type == "MMM", 4]),
                     step = 0.001,
                     min = 0,
                     max = 10000),

        numericInput(inputId = "lambda",
                     label = "Resolution of deposition calculations (higher numbers increase accuracy):",
                     value = as.numeric(params_data[params_data$Type == "lambda", 4]),
                     step = 0.001,
                     min = 0,
                     max = 100)
      )

    } else {
      disabled(
        tagList(
          numericInput(inputId = "IAR",
                       label = paste0("Intended Application Rate (", params_data[params_data$Type == "IAR", "Units"], "):"),
                       value = as.numeric(params_data[params_data$Type == "IAR", 4]),
                       step = 0.0000001,
                       min = 0,
                       max = 100),
          numericInput(inputId = "xactive",
                       label = paste0("Concentration in tank solution (", params_data[params_data$Type == "xactive", "Units"], "):"),
                       value = as.numeric(params_data[params_data$Type == "xactive", 4]),
                       step = 0.0000001,
                       min = 0,
                       max = 1),

          numericInput(inputId = "FD",
                       label = paste0("Downwind field depth (", params_data[params_data$Type == "FD", "Units"], "):"),
                       value = as.numeric(params_data[params_data$Type == "FD", 4]),
                       step = 0.001,
                       min = 0,
                       max = 10000),

          numericInput(inputId = "PL",
                       label = paste0("Crosswind field width (", params_data[params_data$Type == "PL", "Units"], "):"),
                       value = as.numeric(params_data[params_data$Type == "PL", 4]),
                       step = 0.001,
                       min = 0,
                       max = 10000),

          numericInput(inputId = "NozzleSpacing",
                       label = paste0("Space between nozzles on Boom (", params_data[params_data$Type == "NozzleSpacing", "Units"], "):"),
                       value = as.numeric(params_data[params_data$Type == "NozzleSpacing", 4]),
                       step = 0.001,
                       min = 0,
                       max = 100),

          numericInput(inputId = "psipsipsi",
                       label = paste0("Horizontal variation in wind direction around mean direction, 1 stdev (", params_data[params_data$Type == "psipsipsi", "Units"], "):"),
                       value = as.numeric(params_data[params_data$Type == "psipsipsi", 4]),
                       step = 0.001,
                       min = 0,
                       max = 100),

          numericInput(inputId = "MMM",
                       label = paste0("Number of droplet size bins (", params_data[params_data$Type == "MMM", "Units"], "):"),
                       value = as.numeric(params_data[params_data$Type == "MMM", 4]),
                       step = 0.001,
                       min = 0,
                       max = 10000),

          numericInput(inputId = "lambda",
                       label = "Resolution of deposition calculations (higher numbers increase accuracy):",
                       value = as.numeric(params_data[params_data$Type == "lambda", 4]),
                       step = 0.001,
                       min = 0,
                       max = 100)
        )

      )
    }

  })




  #####
  ## Upload params data
  params_data <- reactive({
    req(input$selected_params_dataset)
    input$reset

    if (input$selected_params_dataset == "Example Metric") {
      params <-
        list(
        data = Casanova::params_metric,
        units = "Metric"
        )
    } else if (input$selected_params_dataset == "Example Imperial") {
      params <-
        list(
          data = Casanova::params_english,
          units = "English"
        )
    } else if (input$selected_params_dataset == "Upload file") {
      req(input$params_file_name)
      inFile <- input$params_file_name
      #**SFR we could add in ability for user to select which set of values to use if more
      #than one column of data (i.e., read column names and create drop down menu)
      params_file_data <- as.data.frame(read_csv(inFile$datapath, locale = readr::locale(encoding = "ISO-8859-1")))
      # Guess units
      if ("celcius" %in% tolower(params_file_data$Units)) {
        params_file_units <- "Metric"
      } else if ("fahreneit" %in% tolower(params_file_data$Units)) {
        params_file_units <- "English"
      } else {
        params_file_units <- "Something is wrong with file or units"
      }
      #***SFR need to add in a units validation step

      params <-
        list(
          data = params_file_data,
          units = params_file_units
        )

    } else if (input$selected_params_dataset == "Regulatory Scenarios") {
      #If so, upload the appropriate file
      req(input$scenario_chosen)
      if (input$scenario_chosen == "Germany") {
        params <-
          list(
            data = Params_Germany,
            units = "Metric"
          )
      } else if (input$scenario_chosen == "Spain") {
        params <-
          list(
            data = Params_Spain,
            units = "Metric"
          )
      } else if (input$scenario_chosen == "USA") {
        params <-
          list(
            data = Params_USA,
            units = "English"
          )
      }
      return(params)
    }
  })


  #####
  ## Recreate dataset of params (based on selection and possible modification)
  paramsData <- reactive({
    req(params_data())

    paramsData <- create_paramsData(
      input$Tair,
      input$Patm,
      input$RH,
      input$ch,
      input$psipsipsi,
      input$psipsipsi_method,
      input$rhow,
      input$rhos,
      input$xs0,
      input$rhosoln,
      input$H0,
      input$hcm,
      input$app_p,
      input$angle,
      input$IAR,
      input$xactive,
      input$FD,
      input$PL,
      input$NozzleSpacing,
      input$MMM,
      input$lambda,
      params_data()$units
    )

    return(paramsData)

  })

## Gather inputs and create Scenario file
  scnData <- reactive({
    input$reset
    # req(input$Scenario_ID)
    # req(DDD_data())
    # req(DSD_data())
    # req(paramsData())
    # req(params_data()$units)
    # req(paramsWT_reactive$data)

    scnData <-
    list(
      Scenario_ID = input$Scenario_ID,
      DDDparamsData = DDD_data(),
      DSDData = DSD_data(),
      paramsData = paramsData(),
      Params_Units = params_data()$units,
      Params_ID = 1, #***SFR Just setting to 1
      paramsWT = paramsWT_reactive$data
    )

    return(scnData)
  })



## Run the models
  # results <- eventReactive(input$generate, {
  #
  #   cat("Begin calculations")
  #
  #     Casanova::runCasanova(
  #     scnFile = scnData(),
  #     DDDparamsFile = NULL,
  #     report_folder = NULL,
  #     curve_fit_ini_file = NULL, #could create input$curvefitDSD as advanced feature
  #     report = F,
  #     curvefitDSD = F,
  #     driver = "shiny"
  #   )
  #
  # })

  ## Run the models
  results <- reactiveValues(calcs = NULL)

  observeEvent(input$generate, {
    # cat("starting calcs\n")

    ## Check that there is wind/height data
    if (!all(apply(scnData()$paramsWT %>%
                  replace(is.na(.), 0) %>%
                  select(c(1, 2)),
                  2,
                  function(x)
                    any(x > 0)),
            na.rm =  T) |
        is.null(scnData())
        ) {
      shinyalert("Oops!", "Check inputs. All parameters must be entered including at least one wind velocity and height measurement", type = "error")
    } else {
      ##***SFR this chunk used to try to debug progress bar not working
      # withProgress(message = 'Calculation in progress',
      #              detail = 'This may take a while...', value = 0, {
      #                for (i in 1:15) {
      #                  incProgress(1/15)
      #                  Sys.sleep(0.25)
      #                  print(i)
      #                }
      #              })
      ## Provide progress for user
      withProgress(message = 'Performing calculations', detail = "percent complete", value = 0, {

      ## Perform all calculations
      results$calcs <-
        Casanova::runCasanova(
          scnFile = scnData(),
          DDDparamsFile = NULL,
          report_folder = NULL,
          curve_fit_ini_file = NULL, #could create input$curvefitDSD as advanced feature
          report = F,
          curvefitDSD = F,
          driver = "shiny"
        )
      cat("finished calcs\n")
      })
    }
  })



  ## Download report
  output$report_download <- downloadHandler(

    # For PDF output, change this to "report.pdf"
    filename = "report.html",

    # filename = paste0(input$Scenario_ID, "_report.html"),
      content = function(file) {
        shiny::withProgress(
          message = paste0("Downloading", input$dataset, " Data"),
          value = 0,
{
      # Copy the report file to a temporary directory before processing it, in
      # case we don't have write permissions to the current working dir (which
      # can happen when deployed).
      tempReport <- file.path(tempdir(), "report.Rmd")
      file.copy("../R/report.Rmd", tempReport, overwrite = TRUE)

      ## Set up parameters to pass to Rmd document
      # Create table of paramaeters used


      all_inputs <- results$calcs$all_inputs
      results <- results$calcs$results


      # replace NULL values with NA in all_inputs
      if (is.null(all_inputs$input_props$z1)){all_inputs$input_props$z1<-NA}
      if (is.null(all_inputs$input_props$ux1)){all_inputs$input_props$ux1<-NA}
      psipsipsi_rep<-all_inputs$input_props$psipsipsi

      wm<-all_inputs$input_props$measurements
      if (wm!=1){
        wm<-NA
        psipsipsi_rep<-NA
      }

      #browser()
      input_params <- tibble("Dry air temperature" = all_inputs$input_props$Tair,
                             "Barometric pressure" = all_inputs$input_props$Patm,
                             "Relative humidity" = all_inputs$input_props$RH,
                             # "Number of wind measurements" = wm,
                             # "Elevation of wind speed (1)" = psipsipsi_rep,
                             # "MPH wind speed (1)" = all_inputs$input_props$ux1,
                             "Density of pure water in droplet" = all_inputs$input_props$rhow,
                             "Density of dissolved solids in droplet" = all_inputs$input_props$rhos,
                             "Mass fraction total dissolved solids in solution" = all_inputs$input_props$xs0,
                             "Height of nozzle above ground" = all_inputs$input_props$H0,
                             "Canopy height (Droplet Transport Calculation)" = all_inputs$input_props$hcm,
                             "Nozzle pressure" = all_inputs$input_props$app_p,
                             "Nozzle angle" = all_inputs$input_props$angle,
                             "Mix density" = all_inputs$input_props$rhosoln,
                             "Intended Application Rate" = all_inputs$input_props$IAR,
                             "Conc in tank solution" = all_inputs$input_props$xactive,
                             "Downwind field depth" = all_inputs$input_props$FD,
                             "Crosswind field width" = all_inputs$input_props$PL,
                             "Space between nozzles on Boom" = all_inputs$input_props$NozzleSpacing,
                             "Horizontal variation in wind direction around mean direction, 1 stdev" = psipsipsi_rep,
                             "Dpmax" = all_inputs$input_props$Dpmax,
                             "Dpmin" = all_inputs$input_props$DDpmin,
                             "Number of droplet size bins" = all_inputs$input_props$MMM,
                             "Resolution of deposition calculations" = all_inputs$input_props$lambda
      ) %>%
        pivot_longer(everything(),
                     names_to = "Parameters",
                     values_to = "Value")

      if (params_data()$units == 'English'){
        param_units <- tibble("Dry air temperature" = "Farhenheit",
                              "Barometric pressure" = "mmHg abs",
                              "Relative humidity" = "%",
                              # "Number of wind measurements" = "NA",
                              # "Elevation of wind speed (1)" = "ft",
                              # "MPH wind speed (1)" = "mph",
                              "Density of pure water in droplet" = "lbs/ft3",
                              "Density of dissolved solids in droplet" = "lbs/ft3",
                              "Mass fraction total dissolved solids in solution" = "NA",
                              "Height of nozzle above ground" = "in",
                              "Canopy height" = "in",
                              "Nozzle pressure" = "psi",
                              "Nozzle angle" = "degrees",
                              "Mix density" = "lbs/ft3",
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
      }
      else if (params_data()$units == 'Metric'){
        param_units <- tibble("Dry air temperature" = "Celcius",
                              "Barometric pressure" = "mmHg abs",
                              "Relative humidity" = "%",
                              # "Number of wind measurements" = "NA",
                              #"Elevation of wind speed (1)" = "m",
                              #"MPH wind speed (1)" = "m/s",
                              "Density of pure water in droplet" = "g/cm3",
                              "Density of dissolved solids in droplet" = "g/cm3",
                              "Mass fraction total dissolved solids in solution" = "NA",
                              "Height of nozzle above ground" = "cm",
                              "Canopy height" = "cm",
                              "Nozzle pressure" = "kPa",
                              "Nozzle angle" = "degrees",
                              "Mix density" = "kg/m3",
                              "Intended Application Rate" = "kg/ha",
                              "Conc in tank solution" = "wtfraction",
                              "Downwind field depth" = "m",
                              "Crosswind field width" = "m",
                              "Space between nozzles on Boom" = "cm",
                              "Horizontal variation in wind direction around mean direction, 1 stdev" = "degrees",
                              "Dpmax" = "µm",
                              "Dpmin" = "µm",
                              "Number of droplet size bins" = "MMM",
                              "Resolution of deposition calculations" = "NA"
        ) %>%
          pivot_longer(everything(),
                       names_to = "Parameters",
                       values_to = "Units")
      }

      #browser()

      input_params_units <- left_join(x = input_params,
                                      y = param_units,
                                      by = "Parameters")


      # Need to edits this one: XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXs
      params <- list(#input_filename = "Superceded code",
        input_scenarioID = input$Scenario_ID,
        input_params = input_params_units,
        step1_results_plot = results$psd_pars$plot,
        step1_results_table = results$psd_pars$table,
        step1_results_stats = results$psd_stats,
        step2_results = results$Twb,
        step3_results = results$wvprofile_params,
        step4_results = results$All_droplet_data,
        step5_results = results$deposition,
        input_paramsWT = scnData()$paramsWT
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
    }
  )

  # ## Generate report
  # report <- reactive({
  #
  #   # report <- "../sample_data/reports/Scenario 1 report.html"
  #   cat("creating report")
  #
    # report <- Casanova::write_report(i = 1,
    #                        all_inputs = results$calcs$all_inputs,
    #                        results = results$calcs$results,
    #                        report_folder = NULL,
    #                        paramsUnits = results$calcs$paramsUnits,
    #                        driver = "shiny")
  #   return(report)
  # })
  #
  # ## Display report in the app
  # output$md_file <- renderUI({
  #   req(report())
  #
  #   includeHTML(report())
  #   # includeMarkdown(report)
  # })

  # ## Display report in the app
  # output$md_file <- renderUI({
  #   # req(results$calcs)
  #   input$reset
  #
  #   if (is.null(results$calcs)) {
  #     return(NULL)
  #   } else {
  #
  #   includeHTML(Casanova::write_report(i = 1,
  #                                        all_inputs = results$calcs$all_inputs,
  #                                        results = results$calcs$results,
  #                                        report_folder = NULL,
  #                                        paramsUnits = results$calcs$paramsUnits,
  #                                        driver = "shiny"))
  #
  #   }
  #   # includeMarkdown(report)
  # })



  # ## Download report
  # output$report_pdf <- downloadHandler(downloadHandler(
  #   filename = paste0(input$Scenario_ID, "_report.pdf"),
  #   content =
  #     function(file) {
  #       out <- Casanova::write_report(
  #         i = 1,
  #         all_inputs = practice$all_inputs,
  #         results = practice$results,
  #         report_folder = filename,
  #         paramsUnits = practice$paramsUnits,
  #         driver = "shiny"
  #       )
  #
  #       file.rename(out, file)
  #     }
  # ))








  # # For Debugging purposes
  # output$contents <- renderTable({
  #   params_data()$units
  #   # scnData()$paramsWT
  #   })


  #***SFR this can be added in next itteration of the app
  # ## Output example data file for user if requested
  # output$download_created_params_file <- downloadHandler(
  #
  #   filename = function() {
  #     #***SFR add in here params ID and params type
  #     paste("paramsData_", params_ID, "_", params_type, ".csv", sep = "")
  #   },
  #   content = function(file) {
  #     #***SFR need to create this created_params_file
  #     write.csv(created_params_file, file, row.names = FALSE)
  #   }
  # )









  # # For Debugging purposes
  # observeEvent(input$reset,{
  #   list_of_inputs <<- reactiveValuesToList(input)
  #   print(list_of_inputs)
  # })
















} #end server

# Run the application
shinyApp(ui = ui, server = server)
