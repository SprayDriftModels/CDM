create_paramsData <- function(
    Tair,
    Patm,
    RH,
    ch,
    psipsipsi,
    psipsipsi_method,
    rhow,
    rhos,
    xs0,
    rhosoln,
    H0,
    hcm,
    app_p,
    angle,
    IAR,
    xactive,
    FD,
    PL,
    NozzleSpacing,
    MMM,
    lambda,
    units) {


  if (units == "Metric") {
    descr_units <- Casanova::params_metric %>% select(Description, Units)
  } else {
    descr_units <- Casanova::params_english %>% select(Description, Units)
  }

  paramsData <-
    tibble(
      Type = c(
        "ID",
        "Tair",
        "Patm",
        "RH",
        "ch",
        "psipsipsi",
        "psipsipsi_method",
        "rhow",
        "rhos",
        "xs0",
        "rhosoln",
        "H0",
        "hcm",
        "app_p",
        "angle",
        "IAR",
        "xactive",
        "FD",
        "PL",
        "NozzleSpacing",
        "MMM",
        "lambda"
      )
    ) %>%
    bind_cols(descr_units) %>%
    mutate(
      Value_1 = c(
        1,
        Tair,
        Patm,
        RH,
        ch,
        psipsipsi,
        psipsipsi_method,
        rhow,
        rhos,
        xs0,
        rhosoln,
        H0,
        hcm,
        app_p,
        angle,
        IAR,
        xactive,
        FD,
        PL,
        NozzleSpacing,
        MMM,
        lambda
      )
    )

  return(paramsData)

}
