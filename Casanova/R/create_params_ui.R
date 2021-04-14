create_params_ui <- function(selected_dataset, type_ui) {

  if (selected_dataset == "Regulatory Scenarios") {
    return(material_card(
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
    ))
  } else if (selected_dataset == "Upload file") {
    return(
      tagList(
              material_card(material_file_input(
                input_id = paste0(type_ui,
                                  "_file_name"),
                label = paste0("Upload ",
                               type_ui,
                               " file"),
                               color = "#80d8ff"
              ))))
  } else {
      return(NULL)
  }
}
