# Training guide architecture

- `TrainingPlanner.lua`: existing dynamic training candidates, probability, and pricing support.
- `TrainingGuide.lua`: shared curated-route calculation, plan assembly, validation, and `AF:RegisterTrainingGuide()`.
- `TrainingMaterials.lua`: material quotations, observed vendor prices, subcraft options, and milestone craft requests.
- `Guides/*.lua`: **data only**; one profession per file, registered during addon initialization.
- `../UI/TrainingPlanner.lua`: shared visual training tree, focus/zoom, material inspector, and crafting UI.

## Guide registration

Files listed after `Training/TrainingGuide.lua` in the `.toc` call:

```lua
local _, AF = ...
AF:RegisterTrainingGuide('leatherworking', {
    {1, 30, 'Light Armor Kit', 29},
    -- ...
})
```

Each row has `{startSkill, endSkill, recipeName, estimatedCrafts, acquisition?, note?}`.
Skill ranges use a half-open interval `[startSkill, endSkill)`; a band from 100 to 115
covers the 15 skill gains from 100→101 through 114→115. Bands must be strictly
contiguous and increase. A registration error identifies gaps or duplicates.

### Important data-quality distinction

These records are **curated editorial references**, not verified live client
skill-up probabilities. The v1.0.30.4 guide pack extends all eight curated routes to skill 300,
updates several recipe transitions and records acquisition notes separately. Recipe knowledge, materials,
price estimates, alternate paths, and unknown-data warnings remain derived by
the shared engine from character snapshots and installed data addons.

Further work: validate recipe IDs, current skill color thresholds, faction and
vendor/trainer offerings in the live Forever client. The route engine deliberately
marks unresolved recipe data as provisional, and will not queue unlearned steps.

## Adding a new guide

1. Add `Training/Guides/<Name>.lua` with `AF:RegisterTrainingGuide(...)`.
2. Add its file to the TOC below `Training/TrainingGuide.lua` and before the UI.
3. Verify row continuity and preview actual in-game skill thresholds.
4. Run guide-plan comparisons and test any conditional/unknown sources before release.

SavedVariables are unchanged; the key remains the lowercase profession name in
`AF.TrainingGuides`. The existing UI uses that registry directly.

## v1.0.30.4 pricing and source rules

- Curated editorial guide coverage: skill **1–300** for all eight crafting guides.
- Rank cap: 300. Apprentice/Journeyman/Expert/Artisan trainer rank changes are
  separate from recipe unlocks; train the next rank before you hit your current cap.
- Guide steps can have acquisition kind `trainer`, `vendor`, `book`, `reputation`
  or `special-trainer`. These describe how to learn the *recipe*, not where its
  *ingredients* come from. Special/faction requirements appear in the step note.
- Material estimates choose the cheaper of the saved Auctionator quote and an
  observed merchant **purchase** price. Never use a vendor **sell** price.
- Before you visit a vendor, a small table of common supply prices can provide
  **reference** estimates. Reference prices are not guarantees of local stock,
  discounts or availability, and are labeled `Vendor estimate` in the UI.
- An observed merchant quote overrides a reference price; buying a multi-item
  merchant bundle is rounded up to whole bundles.
- If neither quote exists for an ingredient, its cost is `unknown`, not zero.

Data sources and caveats are documented in `Training/GuideSources.md`.

## Display consolidation (v1.0.30.5)

`TrainingGuide.lua` calculates the same authoritative per-band `plan.segments` as before. Its `BuildTrainingGuideVisualGroups` helper only groups consecutive recipe/ID and source-equivalent bands into `plan.displayGroups` for the Overview. `plan.displayIndex` maps raw segments to their display node. `plan.routeAudit` reports long 20+ skill-point uses and interrupted reuse. All crafting, queue export, alternatives, inventory, and progress still operate on the original `plan.segments`; never queue a visual group as a single speculative batch.

## v1.0.30.6 route corrections

The curated routes are actively being validated against Forever build 1.60.1.
The Tailoring, Leatherworking and Blacksmithing corrections are threshold-based
editorial recommendations, not a claim of minimum realm-specific gold cost.
The level-290+ Tailoring finish with Mooncloth Robe requires Mooncloth and a
Spinning Wheel and may be much more costly than available learned alternatives.
First Aid skill 75-80 remains an explicitly known green fallback.
The game scan remains the authoritative source of a player's *current*
recipe color; it does not prove future difficulty or remote vendor availability.
Review `GuideSources.md` and each guide's source header for provenance.

## v1.0.30.7 alternative recommendation rules

The guide baseline is **never automatically replaced**. A learned alternate can
receive a theme-aware green highlight only if:

1. It covers the **entire current skill band**, with positive orange/yellow
   estimates at every simulated skill point.
2. The candidate's estimated chance of gaining one skill point is **no worse**
   than the baseline's chance at each point (incomplete/ambiguous thresholds do
   not qualify).
3. Both recipes have **complete material quotes**, including Auctionator and
   usable vendor/merchant estimates. The alternate's estimated **total** cost
   for its expected crafts is strictly lower than the baseline guide's estimate.

Price-only advantages that fail skill-up confidence checks remain normal
alternatives; profitable item sale quotes alone are never a recommendation.
All green recommendations are optional and based on cached quotes. Selecting a
recommended alternative retains its highlight and still uses the existing
crafting and queue protections. This is comparison metadata/UI only, not a
change to the curated recipes, materials, or level simulation.
