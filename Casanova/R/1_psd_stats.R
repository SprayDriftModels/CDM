#' PSD statistics
#'
#' @param y Average DSD fit data:
#' @param Dpdata Corresponding droplet size (in microns)
#'
#' @return list of statical parameters
#' @export
#'
#' @examples
psd_stats<-function(y, Dpdata){
#browser()

  psd_fun<-approxfun(y,Dpdata)

  DV10<-psd_fun(10)
  DV50<-psd_fun(50)
  DV90<-psd_fun(90)
  RS<-(DV90-DV10)/DV50

  DropVol<-4/3*pi*(Dpdata/2*0.000001)^3


  y_inc<-NULL
  # Calculate incremental data
  y_inc[1]<-y[1]
  for (i in 2:length(y)){
    y_inc[i]<-y[i]-y[i-1]
  }


  IN<-y_inc/(4/3*pi*(Dpdata/2*0.000001)^3) # Incremental Number
  IN_per<-IN/sum(IN)*100 # Incremental Number in %
  IN_cum<-NULL          # Cumulative number
  IN_cum[1]<-IN_per[1]
  for (i in 2:length(IN_per)){
    IN_cum[i]<-IN_per[i]+IN_cum[i-1]
  }

  psd_fun3<-approxfun(IN_cum,Dpdata)
  NMD<-psd_fun3(50)

  #browser()
  drop_num<-y_inc/DropVol
  calc_vm<-drop_num*Dpdata^3
  calc_sm<-drop_num*Dpdata^2

  D30<-(sum(calc_vm)/sum(drop_num))^(1/3)
  D32<-sum(calc_vm)/sum(calc_sm)


  psd_fun2<-approxfun(Dpdata,y)
  L141<-psd_fun2(141)
  L100<-psd_fun2(100)
  L150<-psd_fun2(150)

  # Create the dsd plot

  # Format data for plotting
  Rawdata <- tibble(x = Dpdata, y = y_inc, z = "Input Data")

  # Plot the data
  dsd_plot <- ggplot(Rawdata, aes(x = x, y = y, color = z)) +
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

  #browser()
 stats<-tibble(DV10=DV10,DV50=DV50,
             DV90=DV90, NMD=NMD, D30=D30,
             D32=D32,RS=RS,
             L141=L141,L100=L100,L150=L150)

  stat_list<-list(plot=dsd_plot,stats=stats)
  return(stat_list)
}
