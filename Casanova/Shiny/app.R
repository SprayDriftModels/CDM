
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
Default_values_units <- read_csv("default/Default_values_units.csv", locale = readr::locale(encoding = "ISO-8859-1")) #need to set encoding to deal with µ

## Load scenario files
#*** may want to store these differently
Params_Germany <- read_csv("default/testing/Params_Germany.csv", locale = readr::locale(encoding = "ISO-8859-1")) #need to set encoding to deal with µ
Params_Spain <- read_csv("default/testing/Params_Spain.csv", locale = readr::locale(encoding = "ISO-8859-1")) #need to set encoding to deal with µ
Params_USA <- read_csv("default/testing/Params_USA.csv", locale = readr::locale(encoding = "ISO-8859-1")) #need to set encoding to deal with µ


# geochem_long <- read_csv("geochem_long.csv")
# geochem_long$Closure <- factor(geochem_long$Closure, levels = c("Closure In Place", "Closure By Removal"))

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
    shiny::tags$li(
      a(
        href = 'https://www.bayer.com/en/',
        img(
          src = "Bayer_logo.png",
          height = "40px",
          .noWS = "outside"
        ),
        style = "padding-top:5px; padding-bottom:5px"
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
                                                  ## Load Scenario
                                                  material_card(
                                                    title = "Choose Dataset",
                                                    uiOutput('choose_dataset_ui')
                                                  ),

                                                  ## Load Scenario
                                                  # material_card(
                                                  #   title = "Load Data",
                                                  uiOutput('load_data_ui'),
                                                  # ),

                                                  # ## Load Input files
                                                  # material_card(
                                                  #   title = "Load User Input Files",
                                                  #   uiOutput('infiles_ui')
                                                  #   #***delete line below
                                                  #   # fileInput("file1", "Choose CSV File", accept = ".csv")
                                                  #
                                                  # ),
                                                  uiOutput('units_ui'),

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
                                                      ),
                                                      material_column(
                                                        width = 4,
                                                        material_card(
                                                          # title = "",
                                                          depth = 0,
                                                          #*** put save to file here
                                                          downloadBttn(outputId = "download_created_params_file",
                                                                       label = "Download parameters to file",
                                                                       color = "primary")
                                                        )
                                                      )
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
                                                              uiOutput("env_ui")
                                                            )
                                                          )
                                                        )
                                                        # uiOutput("wind_ui")
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
                                                        tableOutput("contents")
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

  ## Create options for canopy/wind speed
  MeasurementOptions = c(1, 2)

  #***SFR use as a template for validation
  # validate(
  #   need(nrow(geochem_filtered()) != 0,
  #        "No Monte Carlo simulations are available for chosen selections. Consider making a different set of selections or selecting âNo Selection (all included)â for clay and/or oxide content on the User Selections page.")
  # )


  ## Select from existing scenarios
  output$choose_dataset_ui <- renderUI({
    input$reset # reset button

    ## material_dropdown does not reset correctly so using selectInput
    selectInput(
      inputId = "selected_dataset",
      label = "Choose dataset to use",
      choices = c("Default Metric / Manual Entry",
                  "Default Imperial / Manual Entry",
                  "Regulatory Scenarios",
                  "Upload your own / Manual Entry"),
      selected = "Default Metric / Manual Entry",
      selectize = TRUE,
      multiple = FALSE
    )

  })


  output$load_data_ui <- renderUI({
    input$reset # reset button
    req(input$selected_dataset)

    if (input$selected_dataset == "Default Imperial / Manual Entry" | input$selected_dataset == "Default Metric / Manual Entry") {
      return(NULL)

    } else if (input$selected_dataset == "Regulatory Scenarios") {
      material_card(
        title = "Select Regulatory Scenario",
        selectInput(
          inputId = "scenario_chosen",
          label = "Select scenario",
          choices = c("Spain",
                      "Germany",
                      "USA"),
          selected = "None",
          multiple = FALSE
        )
      )
    } else if (input$selected_dataset == "Upload your own / Manual Entry") {

      material_card(
        title = "Upload Your Data",
        splitLayout(
          cellWidths = c("33.33%", "33.33%", "33.33%"),
          material_file_input(
            input_id = "params_file",
            label = "Upload params file",
            color = "#80d8ff"
          ),
          material_file_input(
            input_id = "dsd_file",
            label = "Upload DSD file",
            color = "#80d8ff"
          ),
          material_file_input(
            input_id = "ddd_file",
            label = "Upload DDD file",
            color = "#80d8ff"
          )
        )
      )
    }
  })

  #***SFR perhaps we don't need this and can just populate the entry form that has this info
  # ## Select units (and upload those from loaded files)
  # output$units_ui <- renderUI({
  #   req(params_data())
  #
  #   #***SFR could come up with something better, quick fix
  #   Units_found <- unique(ifelse(tolower(params_data()$Units) %in% "ft", "Metric", "Imperial"))
  #
  #   material_card(
  #     title = "System of measurement",
  #     useShinyjs(),
  #     material_radio_button(
  #       input_id = "unit_measurement",
  #       label = "Select units",
  #       choices = c("Imperial", "Metric"),
  #       selected = Units_found,
  #       color = "#80d8ff"
  #     )
  #   )
  # })

  ## Reset input data to NULL
  # ***



  ## Dissable features (i.e., "lock" manual inputs) if scenarios are used
  # enables if condition is true
  # observe({
  #   # toggleState(id = "infiles_ui", condition = input$selected_dataset != "Regulatory Scenarios")
  #   # toggleState(id = "unit_measurement", condition = input$selected_dataset != "Regulatory Scenarios")
  #   toggleState(id = "env_ui", condition = input$selected_dataset != "Regulatory Scenarios")
  #   toggleState(id = "wind_ui", condition = input$selected_dataset != "Regulatory Scenarios")
  #   toggleState(id = "droplet_ui", condition = input$selected_dataset != "Regulatory Scenarios")
  #   toggleState(id = "deposition_ui", condition = input$selected_dataset != "Regulatory Scenarios")
  # })


  ## Set unit labels based on user selection
  #***SFR need to have it adjust based on user input
  #instead now moving into reactive that sets params_data
  # units_data <- reactive({
  #
  #   return(units_data)
  # })


  ## User Inputs for Wind Profile (depends on whether uploaded, scenario, manual entry)
  ##### Elevation
  output$env_ui <- renderUI({
    req(params_data())

    # if (input$selected_dataset != "Regulatory Scenarios") {
    ## Input dry air temp
    tagList(
      useShinyjs(),
      # material_card(
      #   title = "Environmental Variables", #***SFR replcae with "" and use download button instead
      #   depth = 0,
        numericInput(
          inputId = "Tair",
          label = paste0("Dry air temperature (", params_data()[params_data()$ID == "Tair", "Units"], "):"),
          value = as.numeric(params_data()[params_data()$ID == "Tair", 4]),
          step = 0.001,
          min = -50,
          max = 50
        ),
        ## Input Barometric pressure, mmHg abs
        numericInput(
          inputId = "Patm",
          label = paste0("Barometric pressure (", params_data()[params_data()$ID == "Patm", "Units"], "):"),
          value = as.numeric(params_data()[params_data()$ID == "Patm", 4]),
          step = 0.001,
          min = 300,
          #***Is there a good min? https://www.avs.org/AVS/files/c7/c7edaedb-95b2-438f-adfb-36de54f87b9e.pdf
          max = 800
        ),
        ## Input Percent Relative Humidity
        numericInput(
          inputId = "RH",
          label = paste0("Relative humidity (", params_data()[params_data()$ID == "RH", "Units"], "):"),
          value = as.numeric(params_data()[params_data()$ID == "RH", 4]),
          step = 0.001,
          min = 0,
          max = 100
        ),
        ## Input Number of Measurements to use
        selectizeInput(
          inputId = "NumberMeasures_chosen",
          label = 'Canopy/wind measurements',
          choice = c('Choose number of measurements' = '', MeasurementOptions),
          multiple = FALSE,
          selected = NULL
        )
      # )
    )
    # } else {
    # disabled(
    #   tagList(
    #     useShinyjs(),
    #   numericInput(
    #   inputId = "Tair",
    #   label = paste0("Dry air temperature (", params_data()[params_data()$ID == "Tair", "Units"], "):"),
    #   value = as.numeric(params_data()[params_data()$ID == "Tair", 4]),
    #   step = 0.001,
    #   min = -50,
    #   max = 50
    # ),
    # ## Input Barometric pressure, mmHg abs
    # numericInput(
    #   inputId = "Patm",
    #   label = paste0("Barometric pressure (", params_data()[params_data()$ID == "Patm", "Units"], "):"),
    #   value = as.numeric(params_data()[params_data()$ID == "Patm", 4]),
    #   step = 0.001,
    #   min = 300,
    #   #***Is there a good min? https://www.avs.org/AVS/files/c7/c7edaedb-95b2-438f-adfb-36de54f87b9e.pdf
    #   max = 800
    # ),
    #
    # ## Input Percent Relative Humidity
    # numericInput(
    #   inputId = "RH",
    #   label = paste0("Relative humidity (", params_data()[params_data()$ID == "RH", "Units"], "):"),
    #   value = as.numeric(params_data()[params_data()$ID == "RH", 4]),
    #   step = 0.001,
    #   min = 0,
    #   max = 100
    # ),
    #
    # ## Input Number of Measurements to use
    # selectizeInput(
    #   inputId = "NumberMeasures_chosen",
    #   label = 'Canopy/wind measurements',
    #   choice = c('Choose number of measurements' = '', MeasurementOptions),
    #   multiple = FALSE,
    #   selected = NULL
    # )
    # )
    # )
    # }
  })

  ## Set wind profile options based on number of measurements
  #***SFR going to need to set 1 vs 2 measurement ui outside of this so it can work in the disabled()
  output$wind_ui <- renderUI({
    req(params_data())

    if (is.null(input$NumberMeasures_chosen)) {
      return()
    }

    ## If only one measurement
    if (input$NumberMeasures_chosen == 1) {
      tagList(
        numericInput(
          inputId = "z1",
          label = paste0("1st elevation of wind speed (", params_data()[params_data()$ID == "z1", "Units"], "):"),
          value = as.numeric(params_data()[params_data()$ID == "z1", 4]),
          step = 0.001,
          min = 0,
          max = 5000
        ),
        numericInput(
          inputId = "ux1",
          label = paste0("1st wind speed (", params_data()[params_data()$ID == "ux1", "Units"], "):"),
          value = as.numeric(params_data()[params_data()$ID == "ux1", 4]),
          step = 0.001,
          min = 0,
          max = 250
        ),
        numericInput(
          inputId = "ch",
          label = paste0("Crop height (", params_data()[params_data()$ID == "ch", "Units"], "):"),
          value = as.numeric(params_data()[params_data()$ID == "ch", 4]),
          step = 0.001,
          min = 0,
          max = 5000
        )
      )
      ## If more than one measurement
    } else if (input$NumberMeasures_chosen > 1) {
      tagList(
        numericInput(
          inputId = "z1",
          label = paste0("1st elevation of wind speed (", params_data()[params_data()$ID == "z1", "Units"], "):"),
          value = as.numeric(params_data()[params_data()$ID == "z1", 4]),
          step = 0.001,
          min = 0,
          max = 5000
        ),
        numericInput(
          inputId = "ux1",
          label = paste0("1st wind speed (", params_data()[params_data()$ID == "ux1", "Units"], "):"),
          value = as.numeric(params_data()[params_data()$ID == "ux1", 4]),
          step = 0.001,
          min = 0,
          max = 250
        ),
        numericInput(
          inputId = "z2",
          label = paste0("2nd elevation of wind speed (", params_data()[params_data()$ID == "z2", "Units"], "):"),
          value = as.numeric(params_data()[params_data()$ID == "z2", 4]),
          step = 0.00001,
          min = 0,
          max = 5000
        ),
        numericInput(
          inputId = "ux2",
          label = paste0("2nd wind speed (", params_data()[params_data()$ID == "ux2", "Units"], "):"),
          value = as.numeric(params_data()[params_data()$ID == "ux2", 4]),
          step = 0.001,
          min = 0,
          max = 250
        )
      )
    }
  })



  ##### Droplet data info
  output$droplet_ui <- renderUI({
    req(params_data())

    if (input$selected_dataset != "Regulatory Scenarios") {
      tagList(
        numericInput(inputId = "rhow",
                     label = paste0("Density of pure water in droplet (", params_data()[params_data()$ID == "rhow", "Units"], "):"),
                     value = as.numeric(params_data()[params_data()$ID == "rhow", 4]),
                     step = 0.001,
                     min = 0,
                     max = 1),

        numericInput(inputId = "rhos",
                     label = paste0("Density of dissolved solids in droplet (", params_data()[params_data()$ID == "rhos", "Units"], "):"),
                     value = as.numeric(params_data()[params_data()$ID == "rhos", 4]),
                     step = 0.001,
                     min = 0,
                     max = 100),

        numericInput(inputId = "xs0",
                     label = "Mass fraction total dissolved solids in solution:",
                     value = as.numeric(params_data()[params_data()$ID == "xs0", 4]),
                     step = 0.000001,
                     min = 0,
                     max = 1),

        numericInput(inputId = "H0",
                     label = paste0("Height of nozzle above ground (", params_data()[params_data()$ID == "H0", "Units"], "):"),
                     value = as.numeric(params_data()[params_data()$ID == "H0", 4]),
                     step = 0.001,
                     min = 0,
                     max = 1000),

        numericInput(inputId = "hcm",
                     label = paste0("Canopy height (", params_data()[params_data()$ID == "hcm", "Units"], "):"),
                     value = as.numeric(params_data()[params_data()$ID == "hcm", 4]),
                     step = 0.001,
                     min = 0,
                     max = 1000),

        numericInput(inputId = "app_p",
                     label = paste0("Nozzle pressure (", params_data()[params_data()$ID == "app_p", "Units"], "):"),
                     value = as.numeric(params_data()[params_data()$ID == "app_p", 4]),
                     step = 0.001,
                     min = 0,
                     max = 1000),

        numericInput(inputId = "angle",
                     label = paste0("Nozzle angle (", params_data()[params_data()$ID == "angle", "Units"], "):"),
                     value = as.numeric(params_data()[params_data()$ID == "angle", 4]),
                     step = 0.001,
                     min = 0,
                     max = 360),

        numericInput(inputId = "rhosoln",
                     label = paste0("Mix density (", params_data()[params_data()$ID == "rhosoln", "Units"], "):"),
                     value = as.numeric(params_data()[params_data()$ID == "rhosoln", 4]),
                     step = 0.001,
                     min = 0,
                     max = 10000)
      )
    } else {
      disabled(    tagList(
        numericInput(inputId = "rhow",
                     label = paste0("Density of pure water in droplet (", params_data()[params_data()$ID == "rhow", "Units"], "):"),
                     value = as.numeric(params_data()[params_data()$ID == "rhow", 4]),
                     step = 0.001,
                     min = 0,
                     max = 1),

        numericInput(inputId = "rhos",
                     label = paste0("Density of dissolved solids in droplet (", params_data()[params_data()$ID == "rhos", "Units"], "):"),
                     value = as.numeric(params_data()[params_data()$ID == "rhos", 4]),
                     step = 0.001,
                     min = 0,
                     max = 100),

        numericInput(inputId = "xs0",
                     label = "Mass fraction total dissolved solids in solution:",
                     value = as.numeric(params_data()[params_data()$ID == "xs0", 4]),
                     step = 0.000001,
                     min = 0,
                     max = 1),

        numericInput(inputId = "H0",
                     label = paste0("Height of nozzle above ground (", params_data()[params_data()$ID == "H0", "Units"], "):"),
                     value = as.numeric(params_data()[params_data()$ID == "H0", 4]),
                     step = 0.001,
                     min = 0,
                     max = 1000),

        numericInput(inputId = "hcm",
                     label = paste0("Canopy height (", params_data()[params_data()$ID == "hcm", "Units"], "):"),
                     value = as.numeric(params_data()[params_data()$ID == "hcm", 4]),
                     step = 0.001,
                     min = 0,
                     max = 1000),

        numericInput(inputId = "app_p",
                     label = paste0("Nozzle pressure (", params_data()[params_data()$ID == "app_p", "Units"], "):"),
                     value = as.numeric(params_data()[params_data()$ID == "app_p", 4]),
                     step = 0.001,
                     min = 0,
                     max = 1000),

        numericInput(inputId = "angle",
                     label = paste0("Nozzle angle (", params_data()[params_data()$ID == "angle", "Units"], "):"),
                     value = as.numeric(params_data()[params_data()$ID == "angle", 4]),
                     step = 0.001,
                     min = 0,
                     max = 360),

        numericInput(inputId = "rhosoln",
                     label = paste0("Mix density (", params_data()[params_data()$ID == "rhosoln", "Units"], "):"),
                     value = as.numeric(params_data()[params_data()$ID == "rhosoln", 4]),
                     step = 0.001,
                     min = 0,
                     max = 10000)
      ))
    }
  })




  ##### Deposition data info
  output$deposition_ui <- renderUI({
    req(params_data())

    if (input$selected_dataset != "Regulatory Scenarios") {
      tagList(
        numericInput(inputId = "IAR",
                     label = paste0("Intended Application Rate (", params_data()[params_data()$ID == "IAR", "Units"], "):"),
                     value = as.numeric(params_data()[params_data()$ID == "IAR", 4]),
                     step = 0.0000001,
                     min = 0,
                     max = 100),
        numericInput(inputId = "xactive",
                     label = paste0("Concentration in tank solution (", params_data()[params_data()$ID == "xactive", "Units"], "):"),
                     value = as.numeric(params_data()[params_data()$ID == "xactive", 4]),
                     step = 0.0000001,
                     min = 0,
                     max = 1),

        numericInput(inputId = "FD",
                     label = paste0("Downwind field depth (", params_data()[params_data()$ID == "FD", "Units"], "):"),
                     value = as.numeric(params_data()[params_data()$ID == "FD", 4]),
                     step = 0.001,
                     min = 0,
                     max = 10000),

        numericInput(inputId = "PL",
                     label = paste0("Crosswind field width (", params_data()[params_data()$ID == "PL", "Units"], "):"),
                     value = as.numeric(params_data()[params_data()$ID == "PL", 4]),
                     step = 0.001,
                     min = 0,
                     max = 10000),

        numericInput(inputId = "NozzleSpacing",
                     label = paste0("Space between nozzles on Boom (", params_data()[params_data()$ID == "NozzleSpacing", "Units"], "):"),
                     value = as.numeric(params_data()[params_data()$ID == "NozzleSpacing", 4]),
                     step = 0.001,
                     min = 0,
                     max = 100),

        numericInput(inputId = "psipsipsi",
                     label = paste0("Horizontal variation in wind direction around mean direction, 1 stdev (", params_data()[params_data()$ID == "psipsipsi", "Units"], "):"),
                     value = as.numeric(params_data()[params_data()$ID == "psipsipsi", 4]),
                     step = 0.001,
                     min = 0,
                     max = 100),

        numericInput(inputId = "Dpmax",
                     label = paste0("Dpmax (", params_data()[params_data()$ID == "Dpmax", "Units"], "):"),
                     value = as.numeric(params_data()[params_data()$ID == "Dpmax", 4]),
                     step = 0.001,
                     min = 0,
                     max = 10000),

        numericInput(inputId = "Ddpmin",
                     label = paste0("Ddpmin (", params_data()[params_data()$ID == "Ddpmin", "Units"], "):"),
                     value = as.numeric(params_data()[params_data()$ID == "Ddpmin", 4]),
                     step = 0.001,
                     min = 0,
                     max = 1000),

        numericInput(inputId = "MMM",
                     label = paste0("Number of droplet size bins (", params_data()[params_data()$ID == "MMM", "Units"], "):"),
                     value = as.numeric(params_data()[params_data()$ID == "MMM", 4]),
                     step = 0.001,
                     min = 0,
                     max = 10000),

        numericInput(inputId = "lambda",
                     label = "Resolution of deposition calculations (higher numbers increase accuracy):",
                     value = as.numeric(params_data()[params_data()$ID == "lambda", 4]),
                     step = 0.001,
                     min = 0,
                     max = 100)
      )

    } else {
      disabled(
        tagList(
          numericInput(inputId = "IAR",
                       label = paste0("Intended Application Rate (", params_data()[params_data()$ID == "IAR", "Units"], "):"),
                       value = as.numeric(params_data()[params_data()$ID == "IAR", 4]),
                       step = 0.0000001,
                       min = 0,
                       max = 100),
          numericInput(inputId = "xactive",
                       label = paste0("Concentration in tank solution (", params_data()[params_data()$ID == "xactive", "Units"], "):"),
                       value = as.numeric(params_data()[params_data()$ID == "xactive", 4]),
                       step = 0.0000001,
                       min = 0,
                       max = 1),

          numericInput(inputId = "FD",
                       label = paste0("Downwind field depth (", params_data()[params_data()$ID == "FD", "Units"], "):"),
                       value = as.numeric(params_data()[params_data()$ID == "FD", 4]),
                       step = 0.001,
                       min = 0,
                       max = 10000),

          numericInput(inputId = "PL",
                       label = paste0("Crosswind field width (", params_data()[params_data()$ID == "PL", "Units"], "):"),
                       value = as.numeric(params_data()[params_data()$ID == "PL", 4]),
                       step = 0.001,
                       min = 0,
                       max = 10000),

          numericInput(inputId = "NozzleSpacing",
                       label = paste0("Space between nozzles on Boom (", params_data()[params_data()$ID == "NozzleSpacing", "Units"], "):"),
                       value = as.numeric(params_data()[params_data()$ID == "NozzleSpacing", 4]),
                       step = 0.001,
                       min = 0,
                       max = 100),

          numericInput(inputId = "psipsipsi",
                       label = paste0("Horizontal variation in wind direction around mean direction, 1 stdev (", params_data()[params_data()$ID == "psipsipsi", "Units"], "):"),
                       value = as.numeric(params_data()[params_data()$ID == "psipsipsi", 4]),
                       step = 0.001,
                       min = 0,
                       max = 100),

          numericInput(inputId = "Dpmax",
                       label = paste0("Dpmax (", params_data()[params_data()$ID == "Dpmax", "Units"], "):"),
                       value = as.numeric(params_data()[params_data()$ID == "Dpmax", 4]),
                       step = 0.001,
                       min = 0,
                       max = 10000),

          numericInput(inputId = "Ddpmin",
                       label = paste0("Ddpmin (", params_data()[params_data()$ID == "Ddpmin", "Units"], "):"),
                       value = as.numeric(params_data()[params_data()$ID == "Ddpmin", 4]),
                       step = 0.001,
                       min = 0,
                       max = 1000),

          numericInput(inputId = "MMM",
                       label = paste0("Number of droplet size bins (", params_data()[params_data()$ID == "MMM", "Units"], "):"),
                       value = as.numeric(params_data()[params_data()$ID == "MMM", 4]),
                       step = 0.001,
                       min = 0,
                       max = 10000),

          numericInput(inputId = "lambda",
                       label = "Resolution of deposition calculations (higher numbers increase accuracy):",
                       value = as.numeric(params_data()[params_data()$ID == "lambda", 4]),
                       step = 0.001,
                       min = 0,
                       max = 100)
        )

      )
    }

  })


  # # Upload PSD data
  # params_data <- reactive({
  #   #First check if a "scenario" file was selected
  #   if (input$scenario_chosen != "None") {
  #     #If so, upload the appropriate file
  #     if (input$scenario_chosen == "Germany") params_data <- Params_Germany
  #     if (input$scenario_chosen == "Spain") params_data <- Params_Spain
  #     if (input$scenario_chosen == "USA") params_data <- Params_USA
  #     return(params_data)
  #   # then, check for uploaded params file
  #   } else if (!is.null(input$params_file)) {
  #     inFile <- input$params_file
  #     params_data <- read_csv(inFile$datapath)
  #     return(params_data)
  #   } else {
  #     params_data <- params_data()
  #     return(params_data)
  #   }
  # })

  ## Upload PSD data
  #***SFR need to add in way to check/validate files and possibly deal with more than one measurement column
  params_data <- reactive({
    req(input$selected_dataset)
    input$reset

    if (input$selected_dataset == "Default Metric / Manual Entry") {
      params_data <-
        Default_values_units %>% select(c(ID, Description, starts_with("Metric")))
      colnames(params_data) <-
        gsub("Metric_", "", colnames(params_data))
      return(params_data)
    } else if (input$selected_dataset == "Default Imperial / Manual Entry") {
      params_data <-
        Default_values_units %>% select(c(ID, Description, starts_with("Imperial")))
      colnames(params_data) <-
        gsub("Imperial_", "", colnames(params_data))
      return(params_data)
    } else if (input$selected_dataset == "Upload your own / Manual Entry") {
      req(input$params_file)
      inFile <- input$params_file
      params_data <- read_csv(inFile$datapath, locale = readr::locale(encoding = "ISO-8859-1"))
      return(params_data)
    } else if (input$selected_dataset == "Regulatory Scenarios") {
      #If so, upload the appropriate file
      req(input$scenario_chosen)
      if (input$scenario_chosen == "Germany") {
        params_data <- Params_Germany
      } else if (input$scenario_chosen == "Spain") {
        params_data <- Params_Spain
      } else if (input$scenario_chosen == "USA") {
        params_data <- Params_USA
      }
      return(params_data)
    }
  })

  # params_data <- reactive({
  #   inFile <- input$params_file
  #   if (is.null(input$params_file)) {
  #     return(NULL)
  #   }
  #   params_data <- read_csv(inFile$datapath, locale = readr::locale(encoding = "ISO-8859-1"))
  #   return(params_data)
  # })








  ## Use for validation purposes
  # req(file)
  # file <- input$params_file
  # ext <- tools::file_ext(file$datapath)
  # validate(need(ext == "csv", "Please upload a csv file"))

  # ## For Debugging purposes
  # output$contents <- renderTable({
  #   params_data()
  #
  # })







  # params_ID <- "1"
  # params_type <- "English"
  # created_params_file <- Default_values_units

  ## Output example data file for user if requested
  output$download_created_params_file <- downloadHandler(

    filename = function() {
      #***SFR add in here params ID and params type
      paste("paramsData_", params_ID, "_", params_type, ".csv", sep = "")
    },
    content = function(file) {
      #***SFR need to create this created_params_file
      write.csv(created_params_file, file, row.names = FALSE)
    }
  )









  # # For Debugging purposes
  # observeEvent(input$reset,{
  #   list_of_inputs <<- reactiveValuesToList(input)
  #   print(list_of_inputs)
  # })
















} #end server

# Run the application
shinyApp(ui = ui, server = server)
