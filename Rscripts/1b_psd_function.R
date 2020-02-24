plot_fit <- function(y,Dpdata,res){
  
  library(gridExtra)
  
  # Plot the calibration with the input data
  Dp_plot <- (18:1460)
  fDP_plot <- 1/(2 * pi)^0.5 * (res[[5]]/res[[3]] * exp(-1 * (Dp_plot-res[[1]])^2/2/res[[3]]^2) + (1-res[[5]])/res[[4]] * exp(-1 * (Dp_plot-res[[2]])^2/2/res[[4]]^2))
  
  Y <- 0
  for (i in 2:length(Dp_plot<-(18:1460))){
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
      #plot.margin = margin(2, 2, 2, 0, "cm"), #bottom, left, top, right
      legend.title = element_blank(),
      legend.position = "right",
      legend.text = element_text(size = 16),
      # legend.justification=c(1,0),
      # legend.position=c(1,0),
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
                     Value = formatC(param_tb$res, format = "e", digits = 2))
  
  # ## options for table
  # mytheme <- gridExtra::ttheme_default(
  #   core = list(fg_params=list(cex = 1.0)),
  #   colhead = list(fg_params=list(cex = 1.0)),
  #   rowhead = list(fg_params=list(cex = 1.0)))
  #   
  # ## create inset table
  # my_table <- tableGrob(param_tb, rows = NULL, theme = mytheme)
  # 
  # 
  # ### final result 
  # fit_plot_table <- grid.arrange(fit_plot + theme(legend.position = "none"),
  #                                arrangeGrob(legend, my_table),
  #                                ncol = 2)
  
  part1.list <- list("plot" = fit_plot,
                         "table" = param_tb)
  
  return(part1.list)
}
