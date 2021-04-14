
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
DDDparamsData_default <- DDDparamsData <- read_csv("../sample_data/DDD_Params.csv", col_types = 'ddd')

#***SFR could instead add these to the R package and load
DSDData <- read.csv("../sample_data/DSD.csv")

#***SFR could instead add these to the R package and load
DDDData <- read.csv("../sample_data/DDD_Params.csv")


## Currently sourcing these but could add to R package
source("../R/create_paramsData.R")
source("../R/check_units.R")
source("../R/create_params_ui.R")

# #***SFR could instead add these to the R package and load
# paramsWT_English <- read.csv("../sample_data/Wind_Temperature (English).csv")
# paramsWT_Metric <- read.csv("../sample_data/Wind_Temperature (Metric).csv")


## Color choices from here: https://materializecss.com/color.html

#### UI for Shiny App ####
ui <- material_page(
  title = "Casanova Drift Model (CDM)",
  nav_bar_color =  "green lighten-1",
  background_color = "green lighten-4",
  include_fonts = TRUE,
  include_icons = TRUE,

  material_side_nav(
    fixed = TRUE,
    # shiny::tags$li(
    #   a(
    #     href = 'https://www.bayer.com/en/',
    #     img(
    #       src = "Bayer_logo.png",
    #       height = "40px",
    #       .noWS = "outside"
    #     ),
    #     style = "padding-top:5px; padding-bottom:5px"
    #   ),
    #   class = "dropdown"
    # ),
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

                                # material_row(
                                #   material_column(
                                #     width = 12,
                                material_row(
                                  offset = 1,
                                  material_column(width = 12,
                                                  offset = 0.5,

                                                  # tags$br(),
                                                  # tags$br(),
                                                  ## Input: Select a file ----

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

                                                  ## Load Scenario
                                                  # material_card(
                                                  #   title = "Load Data",
                                                  # uiOutput('load_params_data_ui'),
                                                  # ),

                                                  # ## Load Input files
                                                  # material_card(
                                                  #   title = "Load User Input Files",
                                                  #   uiOutput('infiles_ui')
                                                  #   #***delete line below
                                                  #   # fileInput("file1", "Choose CSV File", accept = ".csv")
                                                  #
                                                  # ),
                                                  # uiOutput('units_ui'),

                                                  material_card(
                                                    # title = "Manual input",

                                                    # tags$head(
                                                    #   tags$style(
                                                    #     type = "text/css", #***SFR need to figure out how to set this to material design style
                                                    #     ".nav-tabs {font-size: 16px} ",
                                                    #     "input:invalid {background-color: #FFCCCC;}" #turn red if entry is invalid
                                                    #   )
                                                    # ),
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
                                                    # material_row(
                                                    #   material_column(
                                                    #     width = 4,
                                                    #
                                                    #     uiOutput("env_ui"),
                                                    #     uiOutput("wind_ui")
                                                    #
                                                    #   ),
                                                    #   material_column(
                                                    #     width = 4,
                                                    #
                                                    #     uiOutput("droplet_ui")
                                                    #   ),
                                                    #   material_column(
                                                    #     width = 4,
                                                    #
                                                    #     uiOutput("deposition_ui")
                                                    #
                                                    #   )
                                                    # ),
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
                                                              # uiOutput("windtemp_number_ui"),
                                                              # DTOutput('x1')
                                                            )
                                                          )
                                                        ),
                                                        material_card(
                                                          title = "Wind/temperature profile",
                                                          depth = 1,
                                                          material_row(
                                                            material_column(
                                                              width = 12,
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
                                                        # uiOutput("wind_ui")
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

                                #   )
                                # )
  ),
  material_side_nav_tab_content(side_nav_tab_id = "calculate",
                                material_row(
                                  width = 5,
                                  offset = 1,
                                  material_column(
                                    material_button(
                                      "generate",
                                      "Generate Results",
                                      icon = "offline_bolt",
                                      depth = 3,
                                      color = "light-blue accent-1"
                                    ),
                                    # width = 10,
                                    # offset = 1,
                                    # plotOutput("Water_conc_plot")
                                  )
                                )
  ),
  # material_side_nav_tab_content(side_nav_tab_id = "output",
  #
  #                               )
  # ),
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

  # ## Create options for canopy/wind speed
  # MeasurementOptions = c("Yes", "No")

  #***SFR use as a template for validation
  # validate(
  #   need(nrow(geochem_filtered()) != 0,
  #        "No Monte Carlo simulations are available for chosen selections. Consider making a different set of selections or selecting âNo Selection (all included)â for clay and/or oxide content on the User Selections page.")
  # )

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
              value = "Default Metric Scenario")

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
      # width = 4,
    selectInput(
      inputId = "selected_WTparams_dataset",
      label = "Choose wind/temp params dataset",
      choices = c(
        "Build your own",
        # "Example Metric",
        #           "Example Imperial",
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
      # width = 4,
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
      # width = 4,
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
  ## User Inputs for Wind Profile (depends on whether uploaded, scenario, manual entry)
  ##### Elevation
  output$env_ui <- renderUI({
    req(params_data())

    params_data <- params_data()$data

    # if (input$selected_params_dataset != "Regulatory Scenarios") {
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
      ),
        ## Input Number of Measurements to use
      numericInput(
        inputId = "WTmeasurements",
        label = 'Max number of wind/temp measurements',
        value = as.numeric(params_data[params_data$Type == "measurements", 4]),
        step = 1,
        min = 1,
        max = Inf # limit for this?
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
        paramsWT_file <- as.data.frame(read_csv(inFile$datapath, locale = readr::locale(encoding = "ISO-8859-1")))
      #***SFR add validation step
    } else if (input$selected_WTparams_dataset == "Build your own") {
      paramsWT_file = NULL
    }

    return(paramsWT_file)

  })

  #####
  ## Create WT dataset for UI
  paramsWT <- reactive({
    req(input$WTmeasurements)
    # req(paramsWT_file())
    req(input$selected_WTparams_dataset)
    input$reset

    # ## Get units used
    # params_units <- params_data()$units

    ## If wind_temp file not uploaded
    if (input$selected_WTparams_dataset == "Build your own") {
      #***SFR - can come back and figure out way to adjust example number of rows
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
      DDD_data = DDDData
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

        # numericInput(inputId = "Dpmax",
        #              label = paste0("Dpmax (", params_data[params_data$Type == "Dpmax", "Units"], "):"),
        #              value = as.numeric(params_data[params_data$Type == "Dpmax", 4]),
        #              step = 0.001,
        #              min = 0,
        #              max = 10000),
        #
        # numericInput(inputId = "Ddpmin",
        #              label = paste0("Ddpmin (", params_data[params_data$Type == "Ddpmin", "Units"], "):"),
        #              value = as.numeric(params_data[params_data$Type == "Ddpmin", 4]),
        #              step = 0.001,
        #              min = 0,
        #              max = 1000),

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

          # numericInput(inputId = "Dpmax",
          #              label = paste0("Dpmax (", params_data[params_data$Type == "Dpmax", "Units"], "):"),
          #              value = as.numeric(params_data[params_data$Type == "Dpmax", 4]),
          #              step = 0.001,
          #              min = 0,
          #              max = 10000),
          #
          # numericInput(inputId = "Ddpmin",
          #              label = paste0("Ddpmin (", params_data[params_data$Type == "Ddpmin", "Units"], "):"),
          #              value = as.numeric(params_data[params_data$Type == "Ddpmin", 4]),
          #              step = 0.001,
          #              min = 0,
          #              max = 1000),

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
      params_file_data <- as.data.frame(read_csv(inFile$datapath, locale = readr::locale(encoding = "ISO-8859-1")))

      # Guess units
      if ("celcius" %in% tolower(params_file_data$Units)) {
        params_file_units <- "Metric"
      } else if ("fahreneit" %in% tolower(params_file_data$Units)) {
        params_file_units <- "English"
      }

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

    paramsData <- create_paramsData(
      input$Tair,
      input$Patm,
      input$RH,
      input$ch,
      input$WTmeasurements,
      input$z1,
      input$ux1,
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
      input$lambda
    )

    return(paramsData)

  })




## Run the models
  results <- observeEvent(input$generate, {
    req(paramsWT_reactive$data)
    req(input$Scenario_ID)

    #***SFR need to create user input for curvefitDSD and curve_fit_ini_file
    #***SFR for now just set to NULL, this will need to be an advanced feature

    ## Gather all inputs needed for runCasanova
    # scnData <-
    #   list(
    #     Scenario_ID = input$Scenario_ID, #*-* UI portion
    #     DDDparamsData = input$paramsData,
    #     DSDData = DSDData(),
    #     paramsData = paramsData(),
    #     Params_Units = Params_Units(), #*-* need server side to check and record these for when file loaded manually
    #     Params_ID = 1, #***SFR Just setting to 1
    #     paramsWT = paramsWT()
    #   )

    #***SFR if report = F can it still be created? Probably best to do it outside of runCasanova
    # Casanova::runCasanova(scnFile = scnData,
    #                       DDDparamsFile = NULL,
    #                       report_folder = NULL,
    #                       curve_fit_ini_file = NULL,
    #                       report = F,
    #                       curvefitDSD = input$curvefitDSD,
    #                       driver = "shiny")
  })




  ## Use for validation purposes
  # req(file)
  # file <- input$params_file_name
  # ext <- tools::file_ext(file$datapath)
  # validate(need(ext == "csv", "Please upload a csv file"))

  ## For Debugging purposes
  output$contents <- renderTable({
    paramsData()
  })

  ## For Debugging purposes
  output$contents2 <- renderTable({
    paramsData <- tibble(
      Type = c(
        "Tair",
        "Patm",
        "RH",
        "ch",
        "WTmeasurements",
        "z1"
        # "ux1",
        # "psipsipsi",
        # "psipsipsi_method",
        # "rhow",
        # "rhos",
        # "xs0"
        # "rhosoln",
        # "H0",
        # "hcm",
        # "app_p",
        # "angle",
        # "IAR",
        # "xactive",
        # "FD",
        # "PL",
        # "NozzleSpacing",
        # "MMM",
        # "lambda"
      ),
      Value_1 = c(
        input$Tair,
        input$Patm,
        input$RH,
        input$ch,
        input$WTmeasurements,
        input$z1
        # input$ux1,
        # input$psipsipsi,
        # input$psipsipsi_method,
        # input$rhow,
        # input$rhos,
        # input$xs0
        # rhosoln,
        # H0,
        # hcm,
        # app_p,
        # angle,
        # IAR,
        # xactive,
        # FD,
        # PL,
        # NozzleSpacing,
        # MMM,
        # lambda
      )
    )
    return(paramsData)
    })





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
