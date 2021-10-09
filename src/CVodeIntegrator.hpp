// Copyright (c) 2021 John Buonagurio <jbuonagurio@exponent.com>

#pragma once

#include <array>
#include <memory>
#include <utility>

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
        ctx_(CVodeCreate(CV_BDF)) 
    {
        // Install custom error handler for exception support.
        static cvode::error_handler_callback cb;
        CVodeSetErrHandlerFn(ctx_, cvode::error_handler, &cb);
    }

    ~Integrator()
    {
        if (ctx_) CVodeFree(&ctx_);
    }
    
    void * context() const
    {
        return ctx_;
    }

    void setTolerances(double reltol, const std::array<double, N>& abstol)
    {
        reltol_ = reltol;
        abstol_.reset(N_VNew_Serial(N));
        for (size_t i = 0; i < N; ++i) {
            NV_Ith_S(abstol_,i) = abstol[i];
        }
        CVodeSVtolerances(ctx_, reltol_, abstol_.get());
    }

    // Maximum order for BDF method
    void setMaxOrd(int maxord)
    {
        CVodeSetMaxOrd(ctx_, maxord);
    }

    // Maximum no. of internal steps before tout
    void setMaxNumSteps(int mxsteps)
    {
        CVodeSetMaxNumSteps(ctx_, (long)mxsteps);
    }

    // Flag to activate stability limit detection
    void setStabLimDet(bool stldet)
    {
        CVodeSetStabLimDet(ctx_, (booleantype)stldet);
    }

    // Maximum no. of error test failures
    void setMaxErrTestFails(int maxnef)
    {
        CVodeSetMaxErrTestFails(ctx_, maxnef);
    }

    // Maximum no. of nonlinear iterations
    void setMaxNonlinIters(int maxcor)
    {
        CVodeSetMaxNonlinIters(ctx_, maxcor);
    }

    // Maximum no. of convergence failures
    void setMaxConvFails(int maxncf)
    {
        CVodeSetMaxConvFails(ctx_, maxncf);
    }

    // Cumulative number of internal steps taken by the solver.
    int getNumSteps()
    {
        long nsteps = 0;
        CVodeGetNumSteps(ctx_, &nsteps);
        return (int)nsteps;
    }

    // Number of calls made to the user-supplied RHS function.
    int getNumRhsEvals() const
    {
        long nfevals = 0;
        CVodeGetNumRhsEvals(ctx_, &nfevals);
        return (int)nfevals;
    }

    // Number of calls made to the linear solver's setup function.
    int getNumLinSolvSetups() const
    {
        long nlinsetups = 0;
        CVodeGetNumLinSolvSetups(ctx_, &nlinsetups);
        return (int)nlinsetups;
    }

    // Number of local error test failures that have occurred.
    int getNumErrTestFails() const
    {
        long netfails = 0;
        CVodeGetNumErrTestFails(ctx_, &netfails);
        return (int)netfails;
    }
    
    // Number of nonlinear iterations performed.
    int getNumNonlinSolvIters() const
    {
        long nniters = 0;
        CVodeGetNumNonlinSolvIters(ctx_, &nniters);
        return (int)nniters;
    }

    // Number of nonlinear convergence failures that have occurred.
    int getNumNonlinSolvConvFails() const
    {
        long nncfails = 0;
        CVodeGetNumNonlinSolvConvFails(ctx_, &nncfails);
        return (int)nncfails;
    }

    // Number of calls made to the CVLS Jacobian approximation function.
    int getNumJacEvals() const
    {
        long njevals = 0;
        CVodeGetNumJacEvals(ctx_, &njevals);
        return (int)njevals;
    }

    // Number of calls made to the user-supplied RHS function due to the finite difference
    // Jacobian approximation or finite difference Jacobian-vector product approximation.
    int getNumLinRhsEvals() const
    {
        long nfevalsLS = 0;
        CVodeGetNumLinRhsEvals(ctx_, &nfevalsLS);
        return (int)nfevalsLS;
    }

    void init(CVRhsFn f, double t0, const std::array<double, N>& y0)
    {
        t_ = t0;
        y_.reset(N_VNew_Serial(N));
        for (size_t i = 0; i < N; ++i) {
            NV_Ith_S(y_.get(),i) = y0[i];
        }
        matrix_.reset(SUNDenseMatrix(N, N));
        linsol_.reset(SUNLinSol_Dense(y_.get(), matrix_.get()));
        CVodeInit(ctx_, f, t0, y_.get());
        CVodeSetLinearSolver(ctx_, linsol_.get(), matrix_.get());
    }

    void step(double tout)
    {
        CVode(ctx_, tout, y_.get(), &t_, CV_NORMAL);
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
    void *ctx_;
    double reltol_ = 0;
    N_VectorUniquePtr abstol_;
    N_VectorUniquePtr y_;
    SUNMatrixUniquePtr matrix_;
    SUNLinearSolverUniquePtr linsol_;
    double t_ = 0;
};

} // namespace cvode

