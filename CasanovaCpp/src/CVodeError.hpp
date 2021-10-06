// Copyright (c) 2021 John Buonagurio <jbuonagurio@exponent.com>

#pragma once

#include <cvode/cvode.h>

#include <exception>
#include <string>
#include <system_error>

namespace cvode {
namespace error {

enum cvode_errors
{
    cv_too_much_work      = CV_TOO_MUCH_WORK,
    cv_too_much_acc       = CV_TOO_MUCH_ACC,
    cv_err_failure        = CV_ERR_FAILURE,
    cv_conv_failure       = CV_CONV_FAILURE,
    cv_linit_fail         = CV_LINIT_FAIL,
    cv_lsetup_fail        = CV_LSETUP_FAIL,
    cv_lsolve_fail        = CV_LSOLVE_FAIL,
    cv_rhsfunc_fail       = CV_RHSFUNC_FAIL,
    cv_first_rhsfunc_err  = CV_FIRST_RHSFUNC_ERR,
    cv_reptd_rhsfunc_err  = CV_REPTD_RHSFUNC_ERR,
    cv_unrec_rhsfunc_err  = CV_UNREC_RHSFUNC_ERR,
    cv_rtfunc_fail        = CV_RTFUNC_FAIL,
    cv_nls_init_fail      = CV_NLS_INIT_FAIL,
    cv_nls_setup_fail     = CV_NLS_SETUP_FAIL,
    cv_constr_fail        = CV_CONSTR_FAIL,
    cv_nls_fail           = CV_NLS_FAIL,
    cv_mem_fail           = CV_MEM_FAIL,
    cv_mem_null           = CV_MEM_NULL,
    cv_ill_input          = CV_ILL_INPUT,
    cv_no_malloc          = CV_NO_MALLOC,
    cv_bad_k              = CV_BAD_K,
    cv_bad_t              = CV_BAD_T,
    cv_bad_dky            = CV_BAD_DKY,
    cv_too_close          = CV_TOO_CLOSE,
    cv_vectorop_err       = CV_VECTOROP_ERR,
    cv_proj_mem_null      = CV_PROJ_MEM_NULL,
    cv_projfunc_fail      = CV_PROJFUNC_FAIL,
    cv_reptd_projfunc_err = CV_REPTD_PROJFUNC_ERR,
    cv_unrecognized_err   = CV_UNRECOGNIZED_ERR
};

extern inline const std::error_category& get_cvode_category();

static const std::error_category& cvode_category = get_cvode_category();

} // namespace error
} // namespace cvode

namespace std {

template<>
struct is_error_code_enum<cvode::error::cvode_errors> : public true_type {};

} // namespace std

namespace cvode {
namespace error {

inline std::error_code make_error_code(cvode_errors c) {
    return std::error_code(static_cast<int>(c), get_cvode_category());
}

inline std::error_code make_error_code(int e) {
    return std::error_code(e, get_cvode_category());
}

} // namespace error
} // namespace cvode

namespace cvode {
namespace error {
namespace detail {

class cvode_category : public std::error_category
{
public:
    virtual const char *name() const noexcept override final { return "CVODE"; }
    virtual std::string message(int c) const override final { return CVodeGetReturnFlagName(c); }
};

} // namespace detail

const std::error_category& get_cvode_category() {
    static detail::cvode_category instance;
    return instance;
}

} // namespace error

class system_error : public std::system_error
{
public:
    system_error(std::error_code ec, const char *module, const char *function, const char *msg)
        : std::system_error(ec),
        module_(module),
        function_(function),
        msg_(msg) {}

    const char* what() const noexcept override { return msg_.c_str(); }
    const char* module() const noexcept { return module_.c_str(); }
    const char* function() const noexcept { return function_.c_str(); }

private:
    const std::string module_;
    const std::string function_;
    const std::string msg_;
};

struct error_handler_callback
{
    void operator()(int error_code, const char *module, const char *function, char *msg) const {
        if (error_code < 0) { // CV_WARNING ignored.
            std::error_code ec = error::make_error_code(error_code);
            system_error e(ec, module, function, msg);
            throw e;
        }
    }
};

// Enable using CVodeSetErrHandlerFn(cvode_mem, cvode::error_handler, &cb)
extern "C" inline void error_handler(int error_code, const char *module, const char *function, char *msg, void *data)
{
    if (data) {
        auto cb = static_cast<error_handler_callback *>(data);
        (*cb)(error_code, module, function, msg);
    }
}

} // namespace cvode
