// Copyright (c) 2021 John Buonagurio <jbuonagurio@exponent.com>

#pragma once

#include <array>
#include <memory>
#include <utility>

#include <sundials/sundials_config.h>
#include <sundials/sundials_context.h>
#include <cvode/cvode.h>
#include <nvector/nvector_serial.h>
#include <sunlinsol/sunlinsol_dense.h>
#include <sunmatrix/sunmatrix_dense.h>

#include "CVodeError.hpp"

struct N_VectorUniquePtrDeleter {
    void operator()(N_Vector nv) const { N_VDestroy(nv); }
};

struct SUNMatrixUniquePtrDeleter {
    void operator()(SUNMatrix sm) const { SUNMatDestroy(sm); }
};

struct SUNLinearSolverUniquePtrDeleter {
    void operator()(SUNLinearSolver ls) const { SUNLinSolFree(ls); }
};

using N_VectorUniquePtr = std::unique_ptr<_generic_N_Vector, N_VectorUniquePtrDeleter>;
using SUNMatrixUniquePtr = std::unique_ptr<_generic_SUNMatrix, SUNMatrixUniquePtrDeleter>;
using SUNLinearSolverUniquePtr = std::unique_ptr<_generic_SUNLinearSolver, SUNLinearSolverUniquePtrDeleter>;

namespace cvode {

template<sunindextype N>
struct Integrator
{
    Integrator() :
        mem_(CVodeCreate(CV_BDF, ctx_))
    {
        // Install custom error handler for exception support.
        CVodeSetErrHandlerFn(mem_, cvode::error_handler, &cb_);
    }

    ~Integrator()
    {
        if (mem_) CVodeFree(&mem_);
    }
    
    static const char * version()
    {
        return SUNDIALS_VERSION;
    }

    void setTolerances(double reltol, const std::array<double, N>& abstol)
    {
        reltol_ = reltol;
        abstol_.reset(N_VNew_Serial(N, ctx_));
        for (size_t i = 0; i < N; ++i) {
            NV_Ith_S(abstol_,i) = abstol[i];
        }
        CVodeSVtolerances(mem_, reltol_, abstol_.get());
        cb_.throw_if_error();
    }

    // Maximum order for BDF method
    void setMaxOrd(int maxord)
    {
        CVodeSetMaxOrd(mem_, maxord);
        cb_.throw_if_error();
    }

    // Maximum no. of internal steps before tout
    void setMaxNumSteps(int mxsteps)
    {
        CVodeSetMaxNumSteps(mem_, (long)mxsteps);
        cb_.throw_if_error();
    }

    // Flag to activate stability limit detection
    void setStabLimDet(bool stldet)
    {
        CVodeSetStabLimDet(mem_, (booleantype)stldet);
        cb_.throw_if_error();
    }

    // Maximum no. of error test failures
    void setMaxErrTestFails(int maxnef)
    {
        CVodeSetMaxErrTestFails(mem_, maxnef);
        cb_.throw_if_error();
    }

    // Maximum no. of nonlinear iterations
    void setMaxNonlinIters(int maxcor)
    {
        CVodeSetMaxNonlinIters(mem_, maxcor);
        cb_.throw_if_error();
    }

    // Maximum no. of convergence failures
    void setMaxConvFails(int maxncf)
    {
        CVodeSetMaxConvFails(mem_, maxncf);
        cb_.throw_if_error();
    }

    // Cumulative number of internal steps taken by the solver.
    int getNumSteps()
    {
        long nsteps = 0;
        CVodeGetNumSteps(mem_, &nsteps);
        return (int)nsteps;
    }

    // Number of calls made to the user-supplied RHS function.
    int getNumRhsEvals() const
    {
        long nfevals = 0;
        CVodeGetNumRhsEvals(mem_, &nfevals);
        return (int)nfevals;
    }

    // Number of calls made to the linear solver's setup function.
    int getNumLinSolvSetups() const
    {
        long nlinsetups = 0;
        CVodeGetNumLinSolvSetups(mem_, &nlinsetups);
        return (int)nlinsetups;
    }

    // Number of local error test failures that have occurred.
    int getNumErrTestFails() const
    {
        long netfails = 0;
        CVodeGetNumErrTestFails(mem_, &netfails);
        return (int)netfails;
    }
    
    // Number of nonlinear iterations performed.
    int getNumNonlinSolvIters() const
    {
        long nniters = 0;
        CVodeGetNumNonlinSolvIters(mem_, &nniters);
        return (int)nniters;
    }

    // Number of nonlinear convergence failures that have occurred.
    int getNumNonlinSolvConvFails() const
    {
        long nncfails = 0;
        CVodeGetNumNonlinSolvConvFails(mem_, &nncfails);
        return (int)nncfails;
    }

    // Number of calls made to the CVLS Jacobian approximation function.
    int getNumJacEvals() const
    {
        long njevals = 0;
        CVodeGetNumJacEvals(mem_, &njevals);
        return (int)njevals;
    }

    // Number of calls made to the user-supplied RHS function due to the finite difference
    // Jacobian approximation or finite difference Jacobian-vector product approximation.
    int getNumLinRhsEvals() const
    {
        long nfevalsLS = 0;
        CVodeGetNumLinRhsEvals(mem_, &nfevalsLS);
        return (int)nfevalsLS;
    }

    void init(CVRhsFn f, double t0, const std::array<double, N>& y0)
    {
        t_ = t0;
        y_.reset(N_VNew_Serial(N, ctx_));
        for (size_t i = 0; i < N; ++i) {
            NV_Ith_S(y_.get(),i) = y0[i];
        }
        
        matrix_.reset(SUNDenseMatrix(N, N, ctx_));
        linsol_.reset(SUNLinSol_Dense(y_.get(), matrix_.get(), ctx_));

        CVodeInit(mem_, f, t0, y_.get());
        cb_.throw_if_error();

        CVodeSetLinearSolver(mem_, linsol_.get(), matrix_.get());
        cb_.throw_if_error();
    }

    void step(double tout)
    {
        CVode(mem_, tout, y_.get(), &t_, CV_NORMAL);
        cb_.throw_if_error();
    }

    std::array<double, N> solution() const
    {
        std::array<double, N> y;
        for (size_t i = 0; i < N; ++i) {
            y[i] = NV_Ith_S(y_,i);
        }
        return y;
    }

private:
    sundials::Context ctx_;
    void *mem_;
    error_handler_callback cb_;
    double reltol_ = 0;
    N_VectorUniquePtr abstol_;
    N_VectorUniquePtr y_;
    SUNMatrixUniquePtr matrix_;
    SUNLinearSolverUniquePtr linsol_;
    double t_ = 0;
};

} // namespace cvode

