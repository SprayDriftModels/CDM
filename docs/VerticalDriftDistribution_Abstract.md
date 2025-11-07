# Enhancing Spray Drift Assessment: Integration of Vertical Drift Distribution in the Casanova Drift Model for Non-Target Organism Risk Evaluation

## Abstract

Spray drift modeling has become increasingly important in the regulatory assessment of crop protection product applications, particularly as concerns grow over the potential impacts on non-target organisms, including non-target arthropods (NTAs) and non-target terrestrial plants (NTTPs). Regulatory frameworks demand accurate predictions of drift behavior to ensure the safety of ecosystems adjacent to agricultural fields.

However, assessing the risks to NTAs and NTTPs remains challenging due to the limitations of current models, which primarily generate spray drift deposition curves without accounting for vertical distribution.

The relevance of spray drift to NTAs and NTTPs is significant, as they play critical roles in maintaining biodiversity, ecosystem services, and agricultural productivity. The regulatory assessment of these organisms is complex, often hindered by the difficulty in capturing short-range drift dynamics that affect off-crop capture and exposure.

This study addresses these challenges by leveraging the Casanova spray drift model, which provides enhanced simulation capabilities to estimate not only deposition curves but also vertical drift profiles. The model employs a mechanistic approach, utilizing CVODE (variable-coefficient ordinary differential equation solver) integration to track droplet trajectories. The simulation uses a six-component solution vector comprising vertical position (Z), horizontal position (X), vertical velocity (Vz), horizontal velocity (Vx), water mass (Mw), and horizontal wind velocity (Vvwx). 

By solving coupled ODEs that account for drag forces, evaporation, and wind profile interactions, the model captures the complete three-dimensional transport of droplets from nozzle release through deposition. This enables extraction of vertical drift concentration profiles at specified downwind distances, providing critical exposure data for organisms at different canopy heights.

Our approach involves analyzing the influence of multiple factors on drift behavior. Droplet size distribution is parameterized via non-linear least squares curve fitting. Wind velocity profiles are characterized by friction velocity and friction height. Application technique parameters include nozzle height, pressure, and angle. The model incorporates multiple streamline vectors (typically 11) spanning ejection angles from -40° to -140° to represent the spray fan geometry. 

Our hypothesis posits that the integration of vertical distribution data will yield more robust risk assessments, providing essential information for the protection of sensitive non-target species.

Preliminary results indicate that the Casanova model can effectively represent short-range aerial drift patterns. Validation against SETAC DRAW test cases demonstrates accurate prediction of both horizontal deposition and vertical concentration profiles. The model successfully captures the effects of droplet evaporation (via wet bulb temperature depression calculations), atmospheric stability (through wind profile parameterization), and size-dependent transport on the spatial distribution of drift. 

This advancement is expected to improve risk analysis and foster regulatory compliance, enabling better-informed decisions in crop protection management and contributing to sustainable agricultural practices.

In conclusion, the Casanova drift model represents a valuable tool for addressing the complex challenges associated with assessing spray drift impacts on NTAs and NTTPs. By generating both deposition curves and vertical drift profiles through mechanistic simulation of droplet physics, this model will aid in the development of effective strategies to protect non-target organisms in the context of crop protection applications.

---

**Keywords:** Spray drift modeling, vertical drift distribution, Casanova drift model, non-target arthropods, non-target terrestrial plants, regulatory assessment, environmental risk assessment, crop protection

**Date:** November 2025  
**Version:** 1.0
