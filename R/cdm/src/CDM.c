#ifndef STRICT_R_HEADERS
#define STRICT_R_HEADERS
#endif

#ifndef R_NO_REMAP
#define R_NO_REMAP
#endif

#include <cdm/CDM.h>

#include <R.h>
#include <Rinternals.h>

#include <stdarg.h>
#include <stddef.h>
#include <stdio.h>

/*
 * Call-local capture of CDM diagnostics.
 *
 * CDM emits its error text through a plain varargs handler
 * (cdm_error_handler_t) with no user-data argument, so the capture target must
 * be file-static. This is safe because _cdm() runs inside a single, synchronous
 * .Call(): R serialises native calls, so the buffer is cleared at entry and read
 * before exit within one atomic invocation (no concurrent writers). This
 * replaces the previous global REprintf handler, which only reached the user via
 * fragile stderr redirection.
 */
#define CDM_ERROR_BUFFER_SIZE 8192
static char cdm_error_buffer[CDM_ERROR_BUFFER_SIZE];
static size_t cdm_error_length = 0;

static void cdm_capture_error_handler(const char *format, ...)
{
    if (cdm_error_length >= CDM_ERROR_BUFFER_SIZE - 1) {
        return;
    }

    va_list args;
    va_start(args, format);
    int written = vsnprintf(cdm_error_buffer + cdm_error_length,
                            CDM_ERROR_BUFFER_SIZE - cdm_error_length,
                            format, args);
    va_end(args);

    if (written > 0) {
        cdm_error_length += (size_t) written;
        if (cdm_error_length >= CDM_ERROR_BUFFER_SIZE) {
            /* Output was truncated; clamp to the last writable position. */
            cdm_error_length = CDM_ERROR_BUFFER_SIZE - 1;
        }
    }
}

extern SEXP _cdm(SEXP sconfig)
{
    const char *config = CHAR(STRING_ELT(sconfig, 0));

    /* Reset the call-local capture buffer for this invocation. */
    cdm_error_buffer[0] = '\0';
    cdm_error_length = 0;

    cdm_model_t *model = cdm_create_model(config);

    int rc = cdm_run_model(model);

    /* Structured result: list(status_code, output, message). */
    const char *names[] = {"status_code", "output", "message"};
    SEXP result = Rf_protect(Rf_allocVector(VECSXP, 3));
    SEXP result_names = Rf_protect(Rf_allocVector(STRSXP, 3));
    for (int i = 0; i < 3; ++i) {
        SET_STRING_ELT(result_names, i, Rf_mkChar(names[i]));
    }
    Rf_setAttrib(result, R_NamesSymbol, result_names);

    SET_VECTOR_ELT(result, 0, Rf_ScalarInteger(rc));

    if (rc != 0) {
        cdm_free_model(model);

        const char *message =
            (cdm_error_length > 0) ? cdm_error_buffer
                                   : "CDM model failed with no diagnostic message.";

        SET_VECTOR_ELT(result, 1, R_NilValue);
        SET_VECTOR_ELT(result, 2, Rf_mkString(message));

        Rf_unprotect(2);
        return result;
    }

    char *output = cdm_get_output_string(model);
    SET_VECTOR_ELT(result, 1, Rf_ScalarString(Rf_mkCharCE(output, CE_UTF8)));
    SET_VECTOR_ELT(result, 2, Rf_mkString(""));

    cdm_free_string(output);
    cdm_free_model(model);

    Rf_unprotect(2);
    return result;
}

extern SEXP _version(void)
{
    SEXP result = Rf_protect(Rf_allocVector(STRSXP, 1));
    SET_STRING_ELT(result, 0, Rf_mkCharCE(CDM_VERSION_STRING, CE_UTF8));
    Rf_unprotect(1);
    return result;
}

static const R_CallMethodDef callMethods[] = {
    {"_cdm", (DL_FUNC) &_cdm, 1},
    {"_version", (DL_FUNC) &_version, 0},
    {NULL, NULL, 0}
};

CDM_SYMBOL_EXPORT void R_init_cdm(DllInfo *info)
{
    R_registerRoutines(info, NULL, callMethods, NULL, NULL);
    
    // Writing R Extensions: 5.4 Registering native routines
    R_useDynamicSymbols(info, FALSE);
    R_forceSymbols(info, FALSE);

    // Capture CDM diagnostics into a call-local buffer instead of writing them
    // straight to stderr, so _cdm() can return the message in a structured result.
    cdm_set_error_handler(cdm_capture_error_handler);
}
