create_paramsData <- function(
    Tair,
    Patm,
    RH,
    ch,
    WTmeasurements,
    z1,
    ux1,
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
    lambda) {


  paramsData <- tibble(
    Type = c(
      "Tair",
      "Patm",
      "RH",
      "ch",
      "WTmeasurements",
      "z1",
      "ux1",
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
    ),
    Value_1 = c(
      Tair,
      Patm,
      RH,
      ch,
      WTmeasurements,
      z1,
      ux1,
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


#***SFR do we need to add the units column???


  ##***SFR another approach
  ## Transpose

  # paramsData <- tibble(
  #   Tair = Tair,
  #   Patm = Patm,
  #   RH = RH,
  #   ch = ch,
  #   NumberMeasures_chosen = NumberMeasures_chosen,
  #   z1 = z1,
  #   ux1 = ux1,
  #   psipsipsi = psipsipsi,
  #   psipsipsi_method = psipsipsi_method,
  #   rhow = rhow,
  #   rhos = rhos,
  #   xs0 = xs0,
  #   rhosoln = rhosoln,
  #   H0 = H0,
  #   hcm = hcm,
  #   app_p = app_p,
  #   angle = angle,
  #   IAR = IAR,
  #   xactive = xactive,
  #   FD = FD,
  #   PL = PL,
  #   NozzleSpacing = NozzleSpacing,
  #   MMM = MMM,
  #   lambda = lambda
  # )
  # paramsData = setNames(data.frame(t(paramsData[,])), paramsData[,1])
  # colnames(paramsData) <- c("Type", "Value_1")

  return(paramsData)

}
