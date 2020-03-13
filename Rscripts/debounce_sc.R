# Redefined in global namespace since it's not exported from shiny
debounce_sc <- function(r, millis, priority = 100, domain = getDefaultReactiveDomain(), short_circuit = NULL) 
{
  force(r)
  force(millis)
  if (!is.function(millis)) {
    origMillis <- millis
    millis <- function() origMillis
  }
  v <- reactiveValues(trigger = NULL, when = NULL)
  firstRun <- TRUE
  observe({
    r()
    if (firstRun) {
      firstRun <<- FALSE
      return()
    }
    v$when <- Sys.time() + millis()/1000
  }, label = "debounce tracker", domain = domain, priority = priority)
  # New code here to short circuit the timer when the short_circuit reactive
  # triggers
  if (inherits(short_circuit, "reactive")) {
    observe({
      short_circuit()
      v$when <- Sys.time()
    }, label = "debounce short circuit", domain = domain, priority = priority)
  }
  # New code ends
  observe({
    if (is.null(v$when)) 
      return()
    now <- Sys.time()
    if (now >= v$when) {
      v$trigger <- isolate(v$trigger %OR% 0) %% 999999999 + 
        1
      v$when <- NULL
    }
    else {
      invalidateLater((v$when - now) * 1000)
    }
  }, label = "debounce timer", domain = domain, priority = priority)
  er <- eventReactive(v$trigger, {
    r()
  }, label = "debounce result", ignoreNULL = FALSE, domain = domain)
  primer <- observe({
    primer$destroy()
    er()
  }, label = "debounce primer", domain = domain, priority = priority)
  er
}