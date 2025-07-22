// Copyright (c) 2023 John Buonagurio <jbuonagurio@exponent.com>
// Copyright (c) 2021 Ed Casanova <eduardo.casanova@bayer.com>

#pragma once

#include <memory>

#include "CVodeIntegrator.hpp"
#include "Model.hpp"

namespace cdm {

class DropletTransport
{
public:
    struct Params {
        double z0;     /**< Friction height [cm] */
        double Uf;     /**< Friction velocity [cm/s] */
        double hN;     /**< Height of nozzle above ground [cm] */
        double hC;     /**< Canopy height [cm] */
        double dTwb;   /**< Wet bulb temperature depression [°C] */
        double rhoW;   /**< Density of pure water in droplet (ρW) [g/cm³] */
        double rhoS;   /**< Density of dissolved solids in droplet (ρS) [g/cm³] */
        double rhoL;   /**< Density of sprayed solution (ρL₀) [g/cm³] */
        double rhoA;   /**< Density of wet air (ρA₀) [g/cm³] */
        double muA;    /**< Dynamic viscosity of wet air at film (μA₀) [g·cm⁻¹s⁻¹] */
        double xs0;    /**< Mass fraction total dissolved solids in solution [fraction] */
        double ddd;    /**< Scale factor for maximum deposition time (δδδ) [unitless] */
        /** Derived */
        double Vvwx0;  /**< Horizontal wind velocity profile function [cm/s] */
        double Ms0;    /**< Mass of sprayed solution in droplet [g] */
        double Mw0;    /**< Mass of water in droplet [g] */
    };

    /**
     * Calculates derived values and initializes CVODE solver.
     */
    DropletTransport(const cdm::Model &m);

    /**
     * Calculates droplet transport distance for a given droplet size and velocity.
     * \param[in] Vz0 Vertical component of nozzle velocity [m/s]
     * \param[in] Vx0 Horizontal component of nozzle velocity [m/s]
     * \param[in] dp Droplet diameter [μm]
     * \return Distance [m]
     */
    double operator()(double Vz, double Vx0, double dp0);

    /**
     * Returns the current solution vector (Z, X, Vz, Vx, Mw, Vvwx).
     */
    std::array<double, 6> solution() const
        { return cvi.solution(); }

    /**
     * Returns CVODE integrator statistics.
     */
    cvode::IntegratorStats integratorStats() const
        { return cvi.getIntegratorStats(); }

private:
    cvode::Integrator<6> cvi;
    Params params;
};

} // namespace cdm