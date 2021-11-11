.onLoad <- function(libname, pkgname) {
  library.dynam("cdm", pkgname, libname, now=TRUE)
  invisible()
}

.onUnLoad <- function(libpath) {
  library.dynam.unload("cdm", libpath)
  invisible()
}
