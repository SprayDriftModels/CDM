#' PSD fitting function
#'
#' @param y Average DSD fit data:
#' @param Dpdata Corresponding droplet size (in microns):
#'
#' @return list of res=c(a1,a2,d1,d2,k1), plot, and input data.
#' @export
#'
#' @examples
psd<-function(y, Dpdata){

  Dpmin <- min(Dpdata)
  Dpmax <- max(Dpdata)

  # Data frame with data
  all_dp_data <- data.frame(y, Dpdata)

  # Function to fit
  f<-function(Dp, a1, a2, d1, d2, k1){

    denom11 <- d1*sqrt(2*pi)
    denom12 <- 2*d1^2
    denom21 <- d2*sqrt(2*pi)
    denom22 <- 2*d2^2
    f1<-function(x){exp(-((x-a1)^2)/denom12)/denom11}
    f2<-function(x){exp(-((x-a2)^2)/denom22)/denom21}

    funct<-0

    # The following is needed to non-linear curve estimation tool (nls); it needs output to be a vector
    for (i in 1: length(Dp))
    {
      temp <- 100*(k1*integrate(f1,Dpmin,Dp[[i]])$value+(1-k1)*integrate(f2,Dpmin,Dp[[i]])$value)
      funct <- c(funct,temp)
    }
    funct[-1] # Removes the initialization of the vector
  }


  # AV edits on 7/21/2020 # This preliminary code estimate works

  # fit2 <- nls2(y ~ f(Dpdata, a1,a2,d1,d2,k1), algorithm  = "plinear-random",
  #              start = data.frame(a1 = c(0.1, 1000), a2 = c(0.1, 2000),d1 = c(0.1, 1000),d2 = c(0.1, 1000),k1 = c(0.001, 1)),
  #              control = nls.control(maxiter = 1000))
  #
  print('Non-linear curve fitting of DSD data is starting:')
  # m.sinexp <- nls(y ~ f(Dpdata, a1,a2,d1,d2,k1), data = all_dp_data,start = coef(fit2)[1:5],
  #                 trace = T,
  #                 control=nls.control(maxiter = 500,minFactor =1/1024,warnOnly=T))

  m.sinexp <- nls(y ~ f(Dpdata, a1,a2,d1,d2,k1), data = all_dp_data,start = list(a1=300,a2=800,d1=100,d2=200,k1=0.2),
                  trace = T,
                  control=nls.control(maxiter = 500,minFactor =1/1024,warnOnly=T))
  # Return parameters
  res <- m.sinexp$m$getPars()

  #browser()
  # Plot the calibration with the input data
  Dp_plot <- (Dpmin:Dpmax)
  fDP_plot <- 1/(2 * pi)^0.5 * (res[[5]]/res[[3]] * exp(-1 * (Dp_plot-res[[1]])^2/2/res[[3]]^2) + (1-res[[5]])/res[[4]] * exp(-1 * (Dp_plot-res[[2]])^2/2/res[[4]]^2))

  Y <- 0
  for (i in 2:length(Dp_plot<-(Dpmin:Dpmax))){
    Y[i] <- Y[i-1] + (fDP_plot[i-1] + fDP_plot[i])/2 * (Dp_plot[i]-Dp_plot[i-1]) * 100
  }

  # Format data for plotting
  Fitdata <- tibble(x = Dp_plot, y = Y, z = "Calibrated")
  Rawdata <- tibble(x = Dpdata, y = y, z = "Input Data")
  Fulldata <- rbind(Fitdata, Rawdata) %>% mutate(z = as.factor(z))

  # Plot the data
  fit_plot <- ggplot(Fulldata, aes(x = x, y = y, color = z)) +
    geom_point(size = 2) +
    scale_color_manual(values = c("#3a3f43", "#fc1e1e")) +
    ylab("Volume fraction (%)") +
    xlab("Droplet Size (microns)") +
    guides(colour = guide_legend(override.aes = list(size=4))) +
    theme_bw() +
    theme(
      legend.title = element_blank(),
      legend.position = "right",
      legend.text = element_text(size = 16),
      axis.line = element_line(colour = "black"),
      axis.text.y = element_text(size = 16),
      axis.text.x = element_text(size = 16),
      axis.title.y = element_text(size = 16, vjust= 1.5),
      axis.title.x = element_text(size = 16)
    )

  ## get the legend
  tmp <- ggplot_gtable(ggplot_build(fit_plot))
  leg <- which(sapply(tmp$grobs, function(x) x$name) ==  "guide-box")
  legend <- tmp$grobs[[leg]]

  param_tb <- as.data.frame(res)
  param_tb <- tibble(Parameter = rownames(param_tb),
                     Value = formatC(param_tb$res, format = "f", digits = 2))

  part1.list <- list("res" = res,
                     "plot" = fit_plot,
                     "table" = param_tb,
                     "y" = y,
                     "Dpdata" = Dpdata)

  return(part1.list)
}
