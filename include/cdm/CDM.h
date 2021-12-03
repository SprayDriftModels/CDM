// Copyright (c) 2021 John Buonagurio <jbuonagurio@exponent.com>

#pragma once

// The cdm library version in the form major * 10000 + minor * 100 + patch.
#define CDM_VERSION 10000

#if defined(_WIN32) || defined(__WIN32__) || defined(WIN32) || defined(__CYGWIN__)
  #ifdef __GNUC__
    #define CDM_SYMBOL_EXPORT __attribute__ ((dllexport))
    #define CDM_SYMBOL_IMPORT __attribute__ ((dllimport))
  #else
    #define CDM_SYMBOL_EXPORT __declspec(dllexport)
    #define CDM_SYMBOL_IMPORT __declspec(dllimport)
  #endif
#else
  #define CDM_SYMBOL_EXPORT __attribute__ ((visibility("default")))
  #define CDM_SYMBOL_IMPORT
#endif

#if defined(CDM_STATIC_DEFINE)
  // CDM was compiled as a static library.
  #define CDM_EXPORT
#else
  #if defined(CDM_EXPORTS)
    // Compiling CDM as a shared library.
    #define CDM_EXPORT CDM_SYMBOL_EXPORT
  #else
    // Using CDM as a shared library.
    #define CDM_EXPORT CDM_SYMBOL_IMPORT
  #endif
#endif

struct cdm_model_s;
typedef struct cdm_model_s cdm_model_t;

typedef void (*cdm_error_handler_t)(const char *format, ...);

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Set a custom error handler function for the CDM library routines.
 * \param[in] handler Error handler function
 * \return Previous error handler function
 */
CDM_EXPORT cdm_error_handler_t cdm_set_error_handler(cdm_error_handler_t handler);

/**
 * Initialize a new CDM model object from JSON-formatted configuration data.
 * \param[in] config JSON
 * \return CDM model object
 */
CDM_EXPORT cdm_model_t * cdm_create_model(const char *config);

/**
 * Free memory associated with a CDM model object.
 * \param[in] model CDM model object
 */
CDM_EXPORT void cdm_free_model(cdm_model_t *model);

/**
 * Run a CDM model.
 * \param[in] model CDM model object
 * \return status code (0=success)
 */
CDM_EXPORT int cdm_run_model(cdm_model_t *model);

/**
 * Print model summary to stdout.
 * \param[in] model CDM model object
 */
CDM_EXPORT void cdm_print_report(cdm_model_t *model);

/**
 * Allocate and return a string with JSON-formatted model results.
 * \param[in] model CDM model object
 * \return JSON
 */
CDM_EXPORT char * cdm_get_output_string(cdm_model_t *model);

/**
 * Free memory associated with a string allocated by the CDM library.
 * \param[in] s string
 */
CDM_EXPORT void cdm_free_string(char *s);

#ifdef __cplusplus
}
#endif