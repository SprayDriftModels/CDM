I can't persist memory across sessions, but here's a compact summary you can paste at the start of your next chat:

---

**CDM SETAC Poster — Session Handoff**

**Repo:** CDM  
**Branches:** `feature/vertical-profile` and `publication` (identical, 6 ahead of `main`) — **do NOT merge yet**  
**Key file:** SETAC_poster.qmd (Quarto HTML poster)

**What's done:**
- 5 R-generated figures saved to images (geometry, vertical profile, ground deposition, cumulative, heatmap — all 300 dpi PNG)
- 2 static figures: `gap_analysis.png`, `implementation_status.png`
- Abbreviations expanded (CVODE, ODE, ASABE, VMD, DSD, JSON, DRAW)
- 5 numbered references added (ISO 22866, SETAC DRAW, Rautmann, SUNDIALS, ASAE S572.1)
- Implementation status chart uses orange "In progress" (not red)

**Pending / open items:**
1. **"% IAR" is not standard terminology** — needs replacing with "% of applied rate" or "% AR" throughout the document (text, figure labels, R code axis labels, mermaid diagram). User confirmed the issue but hasn't chosen replacement wording yet.
2. R code in `.qmd` still uses `pct_iar` as variable name — cosmetic, no functional impact.
3. Implement the vertical profile part. 