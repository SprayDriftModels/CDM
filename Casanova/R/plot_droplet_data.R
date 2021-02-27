#' Droplet Transportation Calculator
#'
#' @param All_droplet_data Droplet data
#'
#' @return ggplot of droplet data
#' @export
#'
#' @examples
plot_droplet_data<-function(All_droplet_data){

    droplet_plot <- ggplot(All_droplet_data, aes(x = Xdist, y = Dp.1.23., color = Droplet)) +
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

    return(droplet_plot)
}
