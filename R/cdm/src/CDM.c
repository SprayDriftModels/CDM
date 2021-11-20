#ifndef STRICT_R_HEADERS
#define STRICT_R_HEADERS
#endif

#ifndef R_NO_REMAP
#define R_NO_REMAP
#endif

#include <CDM.h>
#include <R.h>
#include <Rinternals.h>

extern SEXP _cdm(SEXP sconfig)
{
    const char *config = CHAR(STRING_ELT(sconfig, 0));

    cdm_model_t *model = cdm_create_model(config);
    
    int rc = cdm_run_model(model);
    if (rc != 0) {
        cdm_free_model(model);
        return R_NilValue;
    }

    char *output = cdm_get_output_string(model);

    SEXP result = Rf_protect(Rf_allocVector(STRSXP, 1));
    SET_STRING_ELT(result, 0, Rf_mkCharCE(output, CE_UTF8));

    cdm_free_string(output);
    cdm_free_model(model);

    Rf_unprotect(1);
    return result;
}

static const R_CallMethodDef callMethods[] = {
    {"_cdm", (DL_FUNC) &_cdm, 1},
    {NULL, NULL, 0}
};

CDM_SYMBOL_EXPORT void R_init_cdm(DllInfo *info)
{
    R_registerRoutines(info, NULL, callMethods, NULL, NULL);
    
    // Writing R Extensions: 5.4 Registering native routines
    R_useDynamicSymbols(info, FALSE);
    R_forceSymbols(info, FALSE);

    // Set static error handler callback.
    cdm_set_error_handler(REprintf);
}
