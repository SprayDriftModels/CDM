"""Generate schematic diagram of a spray drift experiment field layout."""

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
import numpy as np
from matplotlib.patches import FancyArrowPatch

fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(12, 10), gridspec_kw={'height_ratios': [1, 2]})

# =============================================================================
# PLAN VIEW (Top-Down)
# =============================================================================
ax1.set_xlim(-15, 60)
ax1.set_ylim(-5, 10)
ax1.set_aspect('equal')
ax1.set_title('Plan View (Top-Down)', fontsize=13, fontweight='bold')

# Treated field
field = mpatches.FancyBboxPatch((-14, 0), 12, 8, boxstyle="round,pad=0.2",
                                 facecolor='#90EE90', edgecolor='black', linewidth=1.5)
ax1.add_patch(field)
ax1.text(-8, 4, 'Treated\nField', ha='center', va='center', fontsize=10, fontweight='bold')

# Spray boom (tractor)
ax1.plot([-1, -1], [1, 7], 'k-', linewidth=4)
ax1.plot([-1], [4], 'ks', markersize=10)
ax1.text(-1, -0.5, 'Boom', ha='center', fontsize=8)

# Field edge
ax1.axvline(x=0, color='brown', linestyle='--', linewidth=1.5, label='Field edge')
ax1.text(0, -1.5, 'Field edge', ha='center', fontsize=8, color='brown')

# Wind arrow
ax1.annotate('', xy=(25, 9), xytext=(5, 9),
             arrowprops=dict(arrowstyle='->', lw=2, color='steelblue'))
ax1.text(15, 9.5, 'Wind direction', ha='center', fontsize=10, color='steelblue', fontweight='bold')

# Collector distances
distances = [3, 5, 10, 20, 30, 50]
for d in distances:
    # Ground collectors
    ax1.plot(d, 4, 'ro', markersize=8)
    # Vertical pole (simple line with small cap markers)
    ax1.plot([d, d], [2, 6], 'b-', linewidth=2)
    ax1.plot(d, 6, 'b_', markersize=6, markeredgewidth=2)
    ax1.plot(d, 2, 'b_', markersize=6, markeredgewidth=2)
    ax1.text(d, -0.5, f'{d} m', ha='center', fontsize=8)

# Legend — placed outside plot to avoid overlap
ax1.plot([], [], 'ro', markersize=8, label='Ground collector')
ax1.plot([], [], 'b-', linewidth=2, label='Vertical pole + samplers')
ax1.legend(loc='upper left', bbox_to_anchor=(0.65, -0.15), ncol=3, fontsize=9,
           frameon=True, edgecolor='gray')
ax1.set_xlabel('Downwind distance from field edge (m)', fontsize=10)
ax1.set_yticks([])
ax1.spines['top'].set_visible(False)
ax1.spines['left'].set_visible(False)
ax1.spines['right'].set_visible(False)

# =============================================================================
# SIDE VIEW (Cross-Section)
# =============================================================================
ax2.set_xlim(-8, 55)
ax2.set_ylim(-0.5, 6)
ax2.set_title('Side View (Cross-Section) — Key Model Parameters', fontsize=13, fontweight='bold')

# Ground
ax2.axhspan(-0.5, 0, color='#8B4513', alpha=0.6)
ax2.axhline(y=0, color='black', linewidth=2)

# --- Two canopy zones ---
hC_field = 1.0   # Taller crop in treated field
hC = 0.5         # Receptor surface (downwind) — used by model
field_edge_x = 0  # X=0 is field edge

# Treated field canopy (left of field edge) — different color, NOT used by model
ax2.fill_between([-8, field_edge_x], 0, hC_field, color='#FFD700', alpha=0.3)
ax2.plot([-8, field_edge_x], [hC_field, hC_field], color='#DAA520', linewidth=2, linestyle='-')
ax2.text(-5, hC_field + 0.1, r'$h_{C,\mathrm{field}}$ (not used in model)',
         fontsize=9, color='#B8860B', ha='center', fontstyle='italic')

# Downwind receptor canopy (right of field edge) — used by model
ax2.fill_between([field_edge_x, 55], 0, hC, color='#228B22', alpha=0.3)
ax2.plot([field_edge_x, 55], [hC, hC], color='green', linewidth=2, linestyle='-')
ax2.text(52, hC + 0.08, r'$h_C$', fontsize=11, color='green', fontweight='bold')

# Field edge vertical line
ax2.axvline(x=field_edge_x, color='brown', linestyle='--', linewidth=1.5)
ax2.text(field_edge_x, 5.7, 'Field\nedge', fontsize=8, color='brown', ha='center', va='top')

# Roughness length (downwind)
z0 = 0.065
ax2.plot([field_edge_x, 55], [z0, z0], color='gray', linestyle=':', linewidth=1)
ax2.text(52, z0 + 0.05, r'$z_0$', fontsize=9, color='gray')

# Nozzle (in the field, left of edge)
hN = 2.0
ax2.plot(-3, hN, 'kv', markersize=14)
ax2.plot([-3, -3], [hC_field, hN], 'k-', linewidth=2)
ax2.text(-4.8, hN, r'$h_N$', fontsize=11, fontweight='bold', va='center')

# Nozzle height annotation
ax2.annotate('', xy=(-6, 0), xytext=(-6, hN),
             arrowprops=dict(arrowstyle='<->', lw=1.2, color='black'))
ax2.text(-7.5, hN / 2, f'{hN} m', fontsize=9, ha='center', va='center')

# Canopy height annotations
ax2.annotate('', xy=(-6.5, 0), xytext=(-6.5, hC_field),
             arrowprops=dict(arrowstyle='<->', lw=1.2, color='#DAA520'))
ax2.text(-7.8, hC_field / 2, f'{hC_field} m', fontsize=8, ha='center', va='center', color='#B8860B')

ax2.annotate('', xy=(2, 0), xytext=(2, hC),
             arrowprops=dict(arrowstyle='<->', lw=1.2, color='green'))
ax2.text(3.5, hC / 2, f'{hC} m', fontsize=9, ha='center', va='center', color='green')

# Droplet trajectories (starting from nozzle at x=-3)
# Large droplet — deposits quickly
t_large = np.linspace(0, 1, 100)
x_large = -3 + 11 * t_large**0.8
z_large = hN - (hN - hC) * t_large**1.2
ax2.plot(x_large, z_large, 'r-', linewidth=2, alpha=0.7, label='Large droplet (deposits near)')

# Medium droplet
t_med = np.linspace(0, 1, 100)
x_med = -3 + 25 * t_med**0.7
z_med = hN * (1 - 0.3 * t_med) - 0.5 * (hN - hC) * t_med**1.5
z_med = np.clip(z_med, hC, None)
ax2.plot(x_med, z_med, 'orange', linewidth=2, alpha=0.7, label='Medium droplet')

# Small droplet — stays aloft, drifts far
t_small = np.linspace(0, 1, 100)
x_small = -3 + 53 * t_small**0.6
z_small = hN + 1.5 * np.sin(2 * np.pi * t_small * 0.7) * t_small**0.5 - 0.8 * t_small
z_small = np.clip(z_small, hC + 0.2, None)
ax2.plot(x_small, z_small, 'b-', linewidth=2, alpha=0.7, label='Small droplet (stays aloft)')

# Wind profile (log-law) shown on right side
z_profile = np.linspace(hC + 0.01, 5.5, 50)
Uf = 0.3  # friction velocity
kappa = 0.4
U_z = (Uf / kappa) * np.log((z_profile - hC) / z0)
U_z_scaled = U_z / U_z.max() * 6  # scale for display

ax2_wind = ax2.twiny()
ax2_wind.plot(U_z_scaled, z_profile, 'steelblue', linewidth=2.5, linestyle='--')
ax2_wind.set_xlim(0, 10)
ax2_wind.set_xlabel(r'Wind speed $U(Z) = \frac{U_f}{\kappa} \ln\frac{Z - h_C}{z_0}$',
                    fontsize=10, color='steelblue')
ax2_wind.tick_params(axis='x', colors='steelblue')
ax2_wind.spines['top'].set_color('steelblue')

# Vertical measurement plane
meas_dist = 10
ax2.axvline(x=meas_dist, color='purple', linestyle='-.', linewidth=1.5, alpha=0.5)
ax2.text(meas_dist + 0.5, 5.5, 'Measurement\nplane', fontsize=8, color='purple', va='top')

# Height bins on measurement plane
bin_edges = np.arange(0, 5.5, 0.5)
for h in bin_edges:
    ax2.plot([meas_dist - 0.3, meas_dist + 0.3], [h, h], 'purple', linewidth=0.8, alpha=0.5)

# Stopping condition annotation
ax2.annotate(r'Droplet stops: $Z \leq z_0 + h_C$',
             xy=(8, hC), xytext=(15, 0.1),
             fontsize=9, color='darkred',
             arrowprops=dict(arrowstyle='->', color='darkred', lw=1.2))

# Ground deposition markers
for d in [5, 8, 12, 18, 25, 35]:
    ax2.plot(d, 0, 'r^', markersize=6, alpha=0.6)

ax2.set_xlabel('Downwind distance X (m)', fontsize=11)
ax2.set_ylabel('Height Z (m)', fontsize=11)
ax2.legend(loc='upper right', fontsize=9)
ax2.set_yticks([0, 0.5, 1, 2, 3, 4, 5])

plt.tight_layout()
plt.savefig('docs/assets/images/drift_experiment_schematic.png', dpi=150, bbox_inches='tight')
plt.savefig('docs/assets/images/drift_experiment_schematic.svg', bbox_inches='tight')
plt.close()
print("Saved to docs/assets/images/drift_experiment_schematic.png and .svg")
