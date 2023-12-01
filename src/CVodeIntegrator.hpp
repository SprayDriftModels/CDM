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

/**
 * CVODE integrator statistics.
 */
struct IntegratorStats
{
    long nsteps;     /**< Number of steps taken by CVODE. */
    long nfevals;    /**< Number of calls to the user's `f` function. */
    long nlinsetups; /**< Number of calls made to the linear solver setup function. */
    long netfails;   /**< Number of error test failures. */
    long nniters;    /**< Number of iterations in the nonlinear solver. */
    long nnfails;    /**< Number of convergence failures in the nonlinear solver. */
    int qlast;       /**< Method order used on the last internal step. */
    int qcur;        /**< Method order to be used on the next internal step. */
    double hinused;  /**< Actual value of initial step size. */
    double hlast;    /**< Step size taken on the last internal step. */
    double hcur;     /**< Step size to be attempted on the next internal step. */
    double tcur;     /**< Current internal time reached. */
};

/**
 * CVODE integrator.
 */
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
        CVodeFree(&mem_);
    }
    
    /**
     * Returns the SUNDIALS version string.
     */
    static const char * version()
    {
        return SUNDIALS_VERSION;
    }

    /**
     * Sets a pointer to the user data block for use in CVODE callbacks.
     * \param[in] userdata Pointer to user data.
     */
    void setUserData(void *userdata)
    {
        CVodeSetUserData(mem_, userdata);
        cb_.throw_if_error();
    }
    
    /**
     * Specifies scalar relative tolerance and a vector absolute tolerance (a potentially
     * different absolute tolerance for each vector component).
     * \param[in] reltol Scalar relative tolerance.
     * \param[in] abstol Vector absolute tolerance.
     */
    void setTolerances(double reltol, const std::array<double, N>& abstol)
    {
        abstol_.reset(N_VNew_Serial(N, ctx_));
        for (size_t i = 0; i < N; ++i) {
            NV_Ith_S(abstol_,i) = abstol[i];
        }
        CVodeSVtolerances(mem_, reltol, abstol_.get());
        cb_.throw_if_error();
    }

    /**
     * Specifies the maximum method order.
     */
    void setMaxOrd(int maxord)
    {
        CVodeSetMaxOrd(mem_, maxord);
        cb_.throw_if_error();
    }

    /**
     * Specifies the maximum number of integration steps.
     */
    void setMaxNumSteps(int mxsteps)
    {
        CVodeSetMaxNumSteps(mem_, (long)mxsteps);
        cb_.throw_if_error();
    }

    /**
     * Enables or disables the BDF stability limit detection algorithm.
     */
    void setStabLimDet(bool stldet)
    {
        CVodeSetStabLimDet(mem_, (booleantype)stldet);
        cb_.throw_if_error();
    }

    /**
     * Specifies the maximum number of error test failures during one step.
     */
    void setMaxErrTestFails(int maxnef)
    {
        CVodeSetMaxErrTestFails(mem_, maxnef);
        cb_.throw_if_error();
    }

    /**
     * Specifies the maximum number of warnings issued by the solver for `t + h = t`.
     */
    void setMaxHnilWarns(int mxhnil)
    {
        CVodeSetMaxHnilWarns(mem_, mxhnil);
        cb_.throw_if_error();
    }

    /**
     * Specifies the maximum number of nonlinear iterations during one step.
     */
    void setMaxNonlinIters(int maxcor)
    {
        CVodeSetMaxNonlinIters(mem_, maxcor);
        cb_.throw_if_error();
    }

    /**
     * Specifies the maximum number of nonlinear convergence failures during one step try.
     */
    void setMaxConvFails(int maxncf)
    {
        CVodeSetMaxConvFails(mem_, maxncf);
        cb_.throw_if_error();
    }
	
    /**
     * Specifies the safety factor used in the nonlinear convergence test.
     */
    void setNonlinConvCoef(double nlscoef)
    {
        CVodeSetNonlinConvCoef(mem_, nlscoef);
        cb_.throw_if_error();
    }

    /**
     * Enables or disables integrator-specific fused kernels, if available.
     */
    void setUseIntegratorFusedKernels(bool onoff)
    {
        CVodeSetUseIntegratorFusedKernels(mem_, onoff);
        cb_.throw_if_error();
    }

    /**
     * Prints integrator statistics.
     * \param[out] outfile Pointer to the output file.
     * \param[in] fmt Output format.
     */
    void printAllStats(FILE *outfile, SUNOutputFormat fmt)
    {
        CVodePrintAllStats(mem_, outfile, fmt);
        cb_.throw_if_error();
    }
    
    /**
     * Returns integrator statistics.
     */
    IntegratorStats getIntegratorStats() const
    {
        IntegratorStats s = {};
        CVodeGetIntegratorStats(mem_, &s.nsteps, &s.nfevals,
            &s.nlinsetups, &s.netfails, &s.qlast, &s.qcur,
            &s.hinused, &s.hlast, &s.hcur, &s.tcur);
        CVodeGetNonlinSolvStats(mem_, &s.nniters, &s.nnfails);
        return s;
    }

    /**
     * Returns the current number of integration steps.
     */
    int getNumSteps() const
    {
        long nsteps = 0;
        CVodeGetNumSteps(mem_, &nsteps);
        return (int)nsteps;
    }

    /**
     * Returns the current number of calls made to the user-supplied RHS function.
     */
    int getNumRhsEvals() const
    {
        long nfevals = 0;
        CVodeGetNumRhsEvals(mem_, &nfevals);
        return (int)nfevals;
    }

    /**
     * Returns the current number of calls to the linear solver setup routine.
     */
    int getNumLinSolvSetups() const
    {
        long nlinsetups = 0;
        CVodeGetNumLinSolvSetups(mem_, &nlinsetups);
        return (int)nlinsetups;
    }

    /**
     * Returns the current number of error test failures.
     */
    int getNumErrTestFails() const
    {
        long netfails = 0;
        CVodeGetNumErrTestFails(mem_, &netfails);
        return (int)netfails;
    }

    /**
     * Returns the number of failed steps due to a nonlinear solver failure.
     */
    int getNumStepSolveFails() const
    {
        long nncfails = 0;
        CVodeGetNumStepSolveFails(mem_, &nncfails);
        return (int)nncfails;
    }

    /**
     * Returns the number of order reductions due to the BDF stability limit detection algorithm.
     */
    int getNumStabLimOrderReds() const
    {
        long nslred = 0;
        CVodeGetNumStabLimOrderReds(mem_, &nslred);
        return (int)nslred;
    }

    /**
     * Returns a suggested factor by which the user's tolerances should be scaled when too much
     * accuracy has been requested for some internal step.
     */
    double getTolScaleFactor() const
    {
        double tolsfac = 0;
        CVodeGetTolScaleFactor(mem_, &tolsfac);
        return tolsfac;
    }

    /**
     * Returns the error weight vector for state variables.
     */
    std::array<double, N> getErrWeights()
    {
        std::array<double, N> result = {};
        N_VectorUniquePtr eweight(N_VNew_Serial(N, ctx_));
        CVodeGetErrWeights(mem_, eweight.get());
        for (size_t i = 0; i < N; ++i) {
            result[i] = NV_Ith_S(eweight,i);
        }
        return result;
    }

    /**
     * Returns the estimated local error vector.
     */
    std::array<double, N> getEstLocalErrors()
    {
        std::array<double, N> result = {};
        N_VectorUniquePtr ele(N_VNew_Serial(N, ctx_));
        CVodeGetEstLocalErrors(mem_, ele.get());
        for (size_t i = 0; i < N; ++i) {
            result[i] = NV_Ith_S(ele,i);
        }
        return result;
    }
    
    /**
     * Returns the current number of calls made to the CVLS Jacobian approximation function.
     */
    int getNumJacEvals() const
    {
        long njevals = 0;
        CVodeGetNumJacEvals(mem_, &njevals);
        return (int)njevals;
    }

    /**
     * Returns the current number of calls made to the user-supplied RHS function due to the
     * CVLS finite difference Jacobian approximation or finite difference Jacobian-vector
     * product approximation.
     */
    int getNumLinRhsEvals() const
    {
        long nfevalsLS = 0;
        CVodeGetNumLinRhsEvals(mem_, &nfevalsLS);
        return (int)nfevalsLS;
    }
    /**
     * Returns the cumulative number of linear iterations.
     */
    int getNumLinIters() const
    {
        long nliters = 0;
        CVodeGetNumLinIters(mem_, &nliters);
        return (int)nliters;
    }
    
    /**
     * Returns the cumulative number of linear convergence failures.
     */
    int getNumLinConvFails() const
    {
        long nlcfails = 0;
        CVodeGetNumLinConvFails(mem_, &nlcfails);
        return (int)nlcfails;
    }

    /**
     * Returns the current number of iterations in the nonlinear solver.
     */
    int getNumNonlinSolvIters() const
    {
        long nniters = 0;
        CVodeGetNumNonlinSolvIters(mem_, &nniters);
        return (int)nniters;
    }

    /**
     * Returns the current number of convergence failures in the nonlinear solver.
     */
    int getNumNonlinSolvConvFails() const
    {
        long nnfails = 0;
        CVodeGetNumNonlinSolvConvFails(mem_, &nnfails);
        return (int)nnfails;
    }

    /**
     * Allocates and initializes memory for a problem, and initializes the
     * CVLS linear solver interface.
     * \param[in] f C function which computes the RHS function `f` in the ODE.
     * \param[in] t0 initial value of `t`.
     * \param[in] y0 initial value of `y`.
     */
    void init(CVRhsFn f, double t0, const std::array<double, N>& y0)
    {
        t_ = t0;

        // Allocate the state vector.
        y_.reset(N_VNew_Serial(N, ctx_));
        for (size_t i = 0; i < N; ++i) {
            NV_Ith_S(y_.get(),i) = y0[i];
        }
        
        // Allocate SUNLinearSolver objects.
        matrix_.reset(SUNDenseMatrix(N, N, ctx_));
        linsol_.reset(SUNLinSol_Dense(y_.get(), matrix_.get(), ctx_));

        // Initialize CVODE solver.
        CVodeInit(mem_, f, t0, y_.get());
        cb_.throw_if_error();

        // Initialize CVLS linear solver interface.
        CVodeSetLinearSolver(mem_, linsol_.get(), matrix_.get());
        cb_.throw_if_error();
    }

    /**
     * Reinitializes the CVODE solver for a new problem using existing internal
     * memory. Solution history from the previous integration is removed; any
     * solver options set previously remain in effect.
     * \param[in] t0 initial value of `t`.
     * \param[in] y0 initial value of `y`.
     */
    void reinit(double t0, const std::array<double, N>& y0)
    {
        t_ = t0;

        y_.reset(N_VNew_Serial(N, ctx_));
        for (size_t i = 0; i < N; ++i) {
            NV_Ith_S(y_.get(),i) = y0[i];
        }

        CVodeReInit(mem_, t0, y_.get());
        cb_.throw_if_error();
    }

    /**
     * Integrates the ODE over an interval in `t`.
     * \param[in] tout The next time at which a computed solution is desired.
     */
    void step(double tout)
    {
        CVode(mem_, tout, y_.get(), &t_, CV_NORMAL);
        cb_.throw_if_error();
    }

    /**
     * Returns the solution vector.
     */
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
    void *mem_ = nullptr;
    error_handler_callback cb_;
    N_VectorUniquePtr abstol_;
    N_VectorUniquePtr y_;
    SUNMatrixUniquePtr matrix_;
    SUNLinearSolverUniquePtr linsol_;
    double t_ = 0;
};

} // namespace cvode

